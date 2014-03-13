#
# Engine::Client::KncImpl
#
# Client base class, performs read/write operations on file descriptors
# connected to a server via knc(1)

package Kharon::Engine::Client::UNIX;
use base qw/Kharon::Engine::Client/;

use NEXT;
use IO::Socket;

use Kharon::TransientError qw(:try);
use Kharon::PermanentError qw(:try);

use warnings;
use strict;

sub Connect {
	my $self = shift;
	my $logger = $self->{logger};
	my @errs;

	foreach my $hr (@_) {
		$logger->log('debug', "connect attempt: $hr");

		my $sock = IO::Socket::UNIX->new($hr);
		if (!defined($sock)) {
			# Well, we didn't get a connexion, try the next
			# one in the list...
			my $errmsg = $!;
			if ($errmsg && $@ && index($@, $errmsg) != -1) {
				$errmsg = "";
			}
			$errmsg .= ", " if $errmsg && $@;
			$errmsg .= $@ if $@;
			push(@errs, "connect to " . $hr .
			    " failed: $errmsg");
			next;
		}

		$self->{in} = $self->{out} = $sock;
		$self->{connexion} = $hr;

		my $ret = 0;
		eval {
			$ret = $self->NEXT::Connect();
		};
		return $ret if ($ret == 1);

		undef $self->{in};
		undef $self->{out};
		undef $self->{connexion};
		$logger->log('err', "$@") if $@;
	}

	throw Kharon::PermanentError("Cannot connect: " .
	    join('; ', @errs), 500);
}

1;
