#
# ProtocolEngineServer
#
# Server base class, performs read/write operations on stdin/stdout

package Kharon::Engine::Server;

use base qw/Kharon::Engine::Std/;

use Kharon::TransientError qw(:try);
use Kharon::PermanentError qw(:try);

use warnings;
use strict;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(@_);

	$self->{NAME} = "STDIN/STDOUT Engine Server";

	bless ($self, $class);
	return $self;
}

#
# XXXrcd: we're not doing this for now!  I haven't decided if this is in
#         fact a good idea...  I got rid of the $end passing in all of the
#         protocols on the assumption that if I decide to go ahead with this
#         plan, it will be easy to reproduce.
#
# Send results will encode a list of responses.  Each response which is
# a code reference will be called as it occurs w/o arguments to generate
# a new list which is expanded in place.  Output is generated and flushed
# before each such recursion.  This enables the server to generate and
# send information without buffering enormous returns...
#
#sub send_results {
#	my ($self, $code, @res) = @_;
#	my $i;
#
#	for ($i=0; $i <= $#res; $i++) {
#		last if ref($res[$i]) eq 'CODE';
#	}
#
#	if ($i > $#res) {
#		$self->Write($self->{resp}->Encode($code, 1, @res));
#		return;
#	}
#
#	$self->Write($self->{resp}->Encode($code, 0, @res[0..($i-1)]));
#
#	my @remnants = @res[($i+1) .. $#res] if $i < $#res;
#
#	$self->send_results($code, &$i(), @remnants);
#}

sub do_command {
	my ($self, $handlers, $line) = @_;
	my ($cmd, @args);
	my $log = $self->{logger};

	# Get the command and args
	eval {
		my $ret = $self->{resp}->Unmarshall($line);
		($cmd, @args) = @$ret;
	};
	if ($@) {
		$log->log('err', "Error parsing command: $@");
		$self->Write($self->{resp}->Encode_Error(500,
		    "Error parsing command: $@"));
		return 0;
	}

	# Bail if we aren't provided with a command...
	if (!defined($cmd)) {
		$cmd = '';
	}

	# Bail if we don't have a handler...
	if (!defined($handlers->{$cmd})) {
		$log->cmd_log('err', 400, $cmd, @args);
		$self->Write($self->{resp}->Encode_Error(400,
		    "No handler defined for command [$cmd]"));
		return 0;
	}

	# We get back a list of refs.  Refs to what,
	# you might ask.  Refs to whatever the
	# response object you constructed this PES
	# with expects...

	my $code;
	my $last = 0;
	my @reflist;

	my $func = $handlers->{$cmd};
	eval { ($code, $last, @reflist) = &$func($cmd, @args); };
	if ($@) {
		$code = 599;
		$last = 0;
		(@reflist) = ($@);
	}

	$log->cmd_log('info', $code, $cmd, @args);

	# XXXrcd: keep this in?
	# Cheesy encoding of code refs...
	for my $i (@reflist) {
		if (ref($i) eq 'CODE') {
			$handlers->{"$i"} = sub { shift; (250, 0, &$i(@_)); };
			next;
		}
		if (UNIVERSAL::isa($i, 'UNIVERSAL')) {
			$handlers->{"$i"} = sub {
				my ($self, $method, @argv) = @_;
				my $f = $i->can($method);

				# XXXrcd: better error here...
				die "asdf" if !defined($f);

				return (250, 0, &$f($i, @argv));
			}
		}
	}

	# Use that response object to encode a list of
	# lines to emit, and emit them.

	eval { $self->Write($self->{resp}->Encode($code, @reflist)); };
	if ($@) {
		$code = 599;
		(@reflist) = ($@);
		$self->Write($self->{resp}->Encode($code, @reflist));
	}

	$last;
}

sub Run {
	my ($self, $handlers) = @_;

	if (!defined($handlers)) {
		throw Kharon::PermanentError("No command handlers defined",
		    500);
	}

	# Run initializer
	if (defined($handlers->{INIT})) {
		if (!&{$handlers->{INIT}}()) {
			throw Kharon::PermanentError("Handler INIT error", 500);
		}
	}

	# Print the Banner, if the protocol defines it:
	my $banner = $self->{resp}->can('SendBanner');
	if (defined($banner) && defined(my $b = &$banner($self->{resp}))) {
		$self->Write($self->{resp}->Encode(220, $b));
	}

	my $line;
	my $cmd;
	my $resp;	# One-off responses
	my $code;
	my $last = 0;

	my @reflist;

	my $remainder = '';
	while (!$last) {
		# Retrieve a line from the client
		my $in = $self->Read();
		last if !defined($in);

		$remainder .= $in;

		($line) = ($remainder =~ /^([^\n\r]*(\r\n|\n))/);

		next if !defined($line);

		$remainder = ${^POSTMATCH};

		try {
			$last = $self->do_command($handlers, $line);
		} catch Kharon::KharonError with {
			# Run destructor
			if (defined($handlers->{DESTROY})) {
				&{$handlers->{DESTROY}}();
			}

			shift->chain("Run method terminated")->throw;
		};
	}

	# Run destructor
	if (defined($handlers->{DESTROY})) {
		&{$handlers->{DESTROY}}();
	}

	return 1;
}

sub RunObj {
	my ($self, %args) = @_;
	my %handlers;
	my $cmd;

	my $object = $args{object};

	for $cmd (@{$args{cmds}}) {
		my $code = $object->can($cmd);
		my $handler = sub { shift; (250, 0, &$code($object, @_)); };

		if (!defined($code)) {
			throw Kharon::PermanentError("Object does not contain".
			    " $cmd method");
		}

		$handlers{$cmd} = $handler;
	}

	$args{exitcmds} = ['quit', 'bye'] if !exists($args{exitcmds});
	for $cmd (@{$args{exitcmds}}) {
		$handlers{$cmd} = sub { (220, 1, 'bye') };
	}

	if (ref($args{refercmds}) eq 'ARRAY') {
		my $server = $args{next_server};

		die "RunObj: next_server not defined" if !defined($server);

		for $cmd (@{$args{refercmds}}) {
			$handlers{$cmd} = sub { (301, 0, $server) };
		}
	} elsif (ref($args{refercmds}) eq 'HASH') {
		my %h = %{$args{refercmds}};

		for $cmd (keys %h) {
			$handlers{$cmd} = sub { (301, 0, $h{$cmd}) };
		}
	} elsif (exists($args{refercmds})) {
		die "refercmds must be a list of commands or a hash of " .
		    "cmd->server";
	}

	$self->Run(\%handlers);
}

1;
