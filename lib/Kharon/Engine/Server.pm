#
# ProtocolEngineServer
#
# Server base class, performs read/write operations on stdin/stdout

package Kharon::Engine::Server;

use base qw/Kharon::Engine::Std/;

use Sys::Hostname;

use Kharon::utils qw/getclassvar/;

use Kharon::TransientError qw(:try);
use Kharon::PermanentError qw(:try);

use warnings;
use strict;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(%args);

	$self->{NAME} = "STDIN/STDOUT Engine Server";

	$self->{acl} = $args{acl}	if exists($args{acl});

	bless ($self, $class);
	return $self;
}

sub set_acl {
	my ($self, $acl) =@_;

	$self->{acl} = $acl;
	return;
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
	my ($self, $opts, $handlers, $line) = @_;
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

	# Deal with the exit cmds up front:
	if (exists($opts->{exitcmds}) &&
	    grep { $cmd eq $_ } @{$opts->{exitcmds}}) {
		eval { $self->Write($self->{resp}->Encode(220, 'bye')); };
		return 1;
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

	# Check ACLs if they're defined:
	my $err;
	if (defined($self->{acl})) {
		my $perm;

		eval { $perm = $self->{acl}->check($cmd, @args); };
		$err = $@;
 
		if (!$err && $perm != 1) {
			throw Kharon::PermanentError("ACL object must be " .
			    "defined to throw exceptions", 500);
		}
	}

	my $func = $handlers->{$cmd};

	if (!$err) {
		eval { ($code, $last, @reflist) = &$func($cmd, @args); };
		$err = $@ if $@;
	}

	if ($err) {
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
	my ($self, $opts, $handlers) = @_;

	if (!defined($handlers)) {
		throw Kharon::PermanentError("No command handlers defined",
		    500);
	}

	# Run initializer
	if (defined($opts->{INIT})) {
		if (!&{$opts->{INIT}}()) {
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

	if (defined($self->{acl})) {
		$self->{acl}->set_opt('throw', 1);
	}

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
			$last = $self->do_command($opts, $handlers, $line);
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

	my @rosccmds = getclassvar($object, "KHARON_RO_SC_EXPORT");
	my @roaccmds = getclassvar($object, "KHARON_RO_AC_EXPORT");
	my @rwsccmds = getclassvar($object, "KHARON_RW_SC_EXPORT");
	my @rwaccmds = getclassvar($object, "KHARON_RW_AC_EXPORT");

	my @rocmds = (@rosccmds, @roaccmds);
	my @rwcmds = (@rwsccmds, @rwaccmds);

	my $masterfunc = $object->can("KHARON_MASTER");

	my $cmds      = $args{cmds};
	my $refercmds = $args{refercmds};
	my $exitcmds  = $args{exitcmds};
	my $master    = $args{next_server};	# XXXrcd: legacy
	   $master    = $args{master};

	$cmds      = [@rocmds, @rwcmds]	if !defined($cmds);
	$exitcmds  = ['quit', 'bye']	if !defined($exitcmds);
	$master    = &$masterfunc()	if !defined($master) &&
					    defined($masterfunc);
	undef $master			if  defined($master) &&
					    hostname() eq $master;
	$refercmds = [@rwcmds]		if !defined($refercmds) &&
					    defined($master);

	for $cmd (@$cmds) {
		my $code = $object->can($cmd);
		my $handler = sub { shift; (250, 0, &$code($object, @_)); };

		if (!defined($code)) {
			my $log = $self->{logger};
			$log->log('err', "Object does not contain $cmd method");

			throw Kharon::PermanentError("Object does not contain".
			    " $cmd method");
		}

		$handlers{$cmd} = $handler;
	}

	if (ref($refercmds) eq 'ARRAY') {
		die "RunObj: next_server not defined" if !defined($master);

		for $cmd (@$refercmds) {
			$handlers{$cmd} = sub { (301, 0,
			    { PeerAddr => $master }) };
		}
	} elsif (ref($refercmds) eq 'HASH') {
		my %h = %$refercmds;

		for $cmd (keys %h) {
			$handlers{$cmd} = sub { (301, 0, $h{$cmd}) };
		}
	}

	$self->Run({exitcmds => $exitcmds}, \%handlers);
}

sub RunKncAcceptor {
	my ($self, %args) = @_;
	my $log = $self->{logger};

	#
	# defaults for various settings:

	my $maxconns = 1024;
	my $timeout  = 300;

	#
	# obtain parameters for arguments:

	my $object   = $args{object};
	   $maxconns = $args{maxconns}     if defined($args{maxconns});
	   $timeout  = $args{firsttimeout} if defined($args{firsttimeout});

	#  
	# perform basic sanity checking on supplied parameters:

	if (ref($object) ne 'CODE') {
		die "RunKncAcceptor must be provided a function which ".
		    "generates the object.";
	}

	$log->log('info', 'Starting to listen...');

	my $listener = \*STDIN;

	#
	# Set up signal handlers that will become important later:

	local $SIG{ALRM} = sub { return "This does nothing"; };
	local $SIG{HUP}  = sub { $listener->close(); undef $listener; };

	while ($maxconns-- > 0) {
		my $fh;
		my $ret;

		last if !defined($listener);

		#
		# XXXrcd: alarm use is suboptimal here but convenient.
		#         we rely on alarm to bounce us out of accept()...

		alarm($timeout);
		$ret = accept($fh, $listener);
		alarm(0);

		if (!defined($fh) || ! $ret) {
			$log->log('info', "Timeout: $!");
			last;
		}

		my %knc_vars;
		my $line;
		while (1) {
			$line = <$fh>;
			last if !defined($line);

			chomp($line);
			last if $line eq 'END';

			my ($key, $val) = split(':', $line);
			$knc_vars{$key} = $val;
		}

		if ($line eq 'END') {

			# XXXrcd: maybe, we should not pass knc_vars in
			# directly
			$args{object} = &$object(%knc_vars);

			$self->{in}  = $fh;
			$self->{out} = $fh;

			$self->RunObj(%args);

			undef($args{object});

			undef($self->{in});
			undef($self->{out});
		}

		undef($fh);

		#
		# set the interconnexion timeout value:

		$timeout = 60;
		$timeout = $args{timeout}	if defined($args{timeout});
	}

	$log->log('info', 'Stop listen...');
}

1;
