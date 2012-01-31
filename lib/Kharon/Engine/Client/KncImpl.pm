#
# ProtocolEngineClientKnc
#
# Client base class, performs read/write operations on file descriptors
# connected to a server via knc(1)

package Kharon::Engine::Client::KncImpl;

use base qw/Kharon::Engine::Client::Cmd/;

use warnings;
use strict;

my $knc = "/usr/bin/knc";

sub Connect {
	my $self = shift;
	my $logger = $self->{logger};

	#
	# XXXrcd: we should not really be using $self->{socket} here
	#         but rather $self->{in}/$self->{out}...

	my $sock = $self->{socket};
	my $hr = $self->{connexion};

	$self->SUPER::Connect($knc, "-N" . fileno($sock),
	    "$hr->{KncService}\@$hr->{PeerAddr}");
}

1;
