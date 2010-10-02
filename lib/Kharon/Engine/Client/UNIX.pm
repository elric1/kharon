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

	foreach my $hr (@_) {
		$logger->log('debug', "connect attempt: $hr");

		my $sock = IO::Socket::UNIX->new($hr);
		next if !defined($sock);

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

	throw Kharon::PermanentError("Cannot connect", 500);
}

1;
