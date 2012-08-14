#
# Engine::Client::KncImpl
#
# Client base class, performs read/write operations on file descriptors
# connected to a server via knc(1)

package Kharon::Engine::Client::NetImpl;

use NEXT;
use IO::Socket;
use Fcntl;

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
		return $hr->{$key}	if defined($hr->{key});
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

	my $def = $self->{ServerDefaults};
	my ($ConnectTimeout, $DataTimeout);
	my @errs;

	foreach my $hr (@_) {
		if (defined($hr) && ref($hr) eq '') {
			$hr = string_to_server($def, $hr);
		}

		$ConnectTimeout= firstkey('ConnectTimeout', $hr, $def,  5);
		$DataTimeout   = firstkey('DataTimeout',    $hr, $def, 60);

		validate_server('Connect', $hr);

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
			push(@errs, "connect to " . fmtsrv($hr) .
			    " failed: $!");
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
		$self->{DataTimeout} = $DataTimeout;
		return $ret if ($ret == 1);

		undef $self->{socket};
		undef $self->{connexion};
		$logger->log('err', "$@") if $@;
	}

	throw Kharon::PermanentError("Cannot connect: " .
	    join(',', @errs), 500);
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
