#
# Engine::Client::KncImpl
#
# Client base class, performs read/write operations on file descriptors
# connected to a server via knc(1)

package Kharon::Engine::Client::NetImpl;

use Data::Dumper;

use NEXT;
use IO::Socket;
use Fcntl;
use Time::HiRes qw(sleep);

use Kharon::TransientError qw(:try);
use Kharon::PermanentError qw(:try);

use warnings;
use strict;

sub setdefnoref {
	my ($hr, $key, $val) = @_;

	$hr->{$key} = $val	if defined($val) && !ref($val);
}

#
# This function takes a key and a list of hrs terminated by an optional
# scalar.  It returns the value from the first hr that has it or the scalar.

sub firstkey {
	my ($key, @hrs) = @_;

	for my $hr (@hrs) {
		return $hr		if ref($hr) eq '';
		return $hr->{$key}	if defined($hr->{$key});
	}
}

#
# string_to_server will parse strings of the form:
#
#	[<service>@]<host>[:<port>]

our $SERVICE  = '(?:([^@]+)@)';
our $HOSTNAME = '([-a-zA-Z0-9_.]+)';
our $PORTSPEC = '(?::([-a-zA-Z0-9_]+((\(\d+\)))?))';

sub string_to_server {
	my ($def, $str) = @_;
	my $ret;

	if (! ($str =~ /^$SERVICE?$HOSTNAME$PORTSPEC?$/o)) {
		throw Kharon::PermanentError("improper server fmt: $str", 500);
	}

	$ret->{KncService} = $def->{KncService};
	$ret->{PeerPort}   = $def->{PeerPort};

	$ret->{KncService} = $1	if defined($1);
	$ret->{PeerAddr}   = $2;
	$ret->{PeerPort}   = $3	if defined($3);
	$ret;
}

sub fmtsrv {
	my ($srv) = @_;

	$srv->{PeerAddr} . ':' . $srv->{PeerPort};
}

sub validate_server {
	my ($caller, $s) = @_;
	my @death;

	push(@death, "PeerAddr missing")	if !defined($s->{PeerAddr});
	push(@death, "PeerPort missing")	if !defined($s->{PeerPort});
	push(@death, "KncService missing")	if !defined($s->{KncService});

	return if scalar(@death) == 0;

	my $err = "Kharon::Engine::Client::NetImpl::$caller() passed entry";
	if (defined($s->{PeerAddr})) {
		$err .= " for $s->{PeerAddr}";
	}
	$err .= join(', ', '', @death);

	throw Kharon::PermanentError($err, 500);
}

sub SetServerDefaults {
	my ($self, $srv) = @_;

	$self->{ServerDefaults} = $srv;
}

sub ReConnect {
	my ($self, $in) = @_;
	my $sv = $self->{connexion};

	delete $sv->{PeerAddr};

	if (ref($in) eq 'HASH') {
		setdefnoref($sv, qq{PeerAddr}, $in->{errstr});
		setdefnoref($sv, qq{PeerAddr}, $in->{err});
		setdefnoref($sv, qq{PeerAddr}, $in->{PeerAddr});
		setdefnoref($sv, qq{PeerPort}, $in->{PeerPort});
	}

	if (ref($in) eq 'ARRAY') {
		setdefnoref($sv, qq{PeerAddr}, $in->[0]);
	}

	if (ref($in) eq '') {
		setdefnoref($sv, qq{PeerAddr}, $in);
	}

	validate_server('ReConnect', $sv);

	$self->Disconnect();
	$self->Connect($sv);
}

sub Connect {
	my $self = shift;
	my $logger = $self->{logger};

	die ref($self) . "::Connect requires servers to be passed in.\n" if @_ == 0;

	my $def = $self->{ServerDefaults};
	my ($ConnectTimeout, $DataTimeout);
	my @errs;

	my @hrs;
	foreach my $hr (@_) {
		if (defined($hr) && ref($hr) eq '') {
			$hr = string_to_server($def, $hr);
		}

		push(@hrs, $hr);
	}

	#
	# To ensure that we have enough retries, we expand our original
	# list to contain at least 12 entries by duplicating it.  We add
	# to the host ref the concept of a "wait time" which we set on
	# the first entry each time we begin another duplication.  We use
	# the "wait time" to implement an exponential backoff with a slight
	# random peturbation.  We limit the number of cycles to the length
	# of the list @waits.
	#
	# The main benefit of these retries are our attempts to contact the
	# master after a referral as that list has only a single element in
	# it.

	my $hrcur = 0;
	my $hrmax = @hrs;
	my $wait = 1;
	my @waits = (1, 2, 4);
	while (@hrs < 12) {
		my $hr = { %{$hrs[$hrcur++]} };

		if ($hrcur == 1) {
			$hr->{WaitTime} = shift(@waits) + rand(1);
		}

		if ($hrcur >= $hrmax) {
			$hrcur = 0;
		}

		push(@hrs, $hr);
		last if @waits == 0;
	}

	foreach my $hr (@hrs) {
		$ConnectTimeout= firstkey('ConnectTimeout', $hr, $def,  5);
		$DataTimeout   = firstkey('DataTimeout',    $hr, $def, 60);

		validate_server('Connect', $hr);

		if ($hr->{WaitTime}) {
			sleep($hr->{WaitTime});
		}

		$logger->log('debug',
		    "connect attempt $hr->{PeerAddr}:$hr->{PeerPort}");

		my $sock = IO::Socket::INET->new(
						 Proto => "tcp",
						 PeerAddr => $hr->{PeerAddr},
						 PeerPort => $hr->{PeerPort},
						 Timeout => $ConnectTimeout
						);

		if (!defined($sock)) {
			# Well, we didn't get a connexion, try the next
			# one in the list...
			my $errmsg = $!;
			if ($errmsg && $@ && index($@, $errmsg) != -1) {
				$errmsg = "";
			}
			$errmsg .= ", " if $errmsg && $@;
			$errmsg .= $@ if $@;
			push(@errs, "connect to " . fmtsrv($hr) .
			    " failed: $errmsg");
			next;
		}

		$self->{DataTimeout} = $ConnectTimeout;

		# Get around the fact that IO::Socket apparently
		# marks descriptors FD_CLOEXEC
		fcntl($sock, F_SETFD, 0);

		$self->{socket} = $sock;
		$self->{connexion} = $hr;

		my $ret = 0;
		eval {
			$ret = $self->NEXT::Connect();
		};
		my $err = $@;
		$self->{DataTimeout} = $DataTimeout;
		return $ret if ($ret == 1);

		undef $self->{socket};
		undef $self->{connexion};
		push(@errs, "connect to " . fmtsrv($hr) . " failed: $@") if $@;
	}

	if (@errs == 1) {
		my ($err) = @errs;
		throw Kharon::PermanentError("Cannot connect: $err", 500);
	}
	throw Kharon::PermanentError("Cannot connect:\n\t" .
	    join("\n\t", @errs), 500);
}

sub Disconnect {
	my $self = shift;
	my $logger = $self->{logger};

	if (defined($self->{socket})) {
		$logger->log('debug', "disconnect");
		$self->{socket}->close();
		$self->{socket} = undef;
	}

	$self->NEXT::Disconnect();
}

1;
