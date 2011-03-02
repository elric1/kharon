#
# ProtocolEngineClientCmd
#
# Client base class, performs read/write operations on file descriptors
# connected to a command

package Kharon::Engine::Client::Fork;

use NEXT;
use Socket;
use IO::Socket;

use base qw/Kharon::Engine::Client/;

use Kharon::TransientError qw(:try);
use Kharon::PermanentError qw(:try);

use warnings;
use strict;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = $class->NEXT::new(@_);

	$self->{NAME} = "Forked Child Client Engine";

	bless ($self, $class);
	return $self;
}

sub Connect {
	my ($self, @cmd) = @_;

	my ($infh, $outfh, $kid);
	my $logger = $self->{logger};

	$logger->log('debug', "creating a Kharon::Engine::Client::Fork");

	my ($parent_sock, $kid_sock) =
	    IO::Socket->socketpair(AF_UNIX, SOCK_STREAM, PF_UNSPEC);

	$kid = fork();
	if (!defined($kid)) {
		throw Kharon::PermanentError($!, 500);
	}

	if ($kid == 0) {
		$parent_sock->close();
		return (0, $kid_sock);
	}

	#
	# We're good to go:

	$kid_sock->close();
	$self->{in}  = $self->{out} = $parent_sock;
	if ($self->SUPER::Connect() == 0) {
		die "Connect failed!";
	}
	return ($kid);
}

1;
