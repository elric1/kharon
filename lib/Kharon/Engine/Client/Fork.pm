#
# ProtocolEngineClientCmd
#
# Client base class, performs read/write operations on file descriptors
# connected to a command

package Kharon::Engine::Client::Fork;

use NEXT;
use Socket;
use IO::Socket;
use POSIX ":sys_wait_h";

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
	$self->{autoreap} = 1;

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
	$self->{kid} = $kid;
	return ($kid);
}

sub DESTROY {
	my ($self) = @_;

	return if !$self->{autoreap};		# Reaping not desired
	return if !defined($self->{kid});	# Nothing to do...

	#
	# Otherwise, we have to kill our kid.  We first close the pipes,
	# hoping that helps the child out of our misery.  We then go ahead
	# and start sending it signals in order to force a termination.
	# So, after closing the pipes we loop waiting on the kid with a
	# 0.05 second sleep.  At the end we employ an escalating process
	# of (do nothing, send TERM, send KILL) to help to hasten the
	# demise.

	undef $self->{in};
	undef $self->{out};

	#
	# We have to make $? local here because Perl rather intelligently
	# uses this value in an END {} block to allow you to redefine the
	# exit status that you return.  As waitpid sets $?, this destructor
	# would otherwise override the return code of a program if a valid
	# SSP::Engine::Client::Fork needed to be g/c'd after exit() has been
	# called...

	local $?;

	my $tmp;
	my $kid = $self->{kid};
	for (my $i = 0; $i < 10; $i++) {
		$tmp = waitpid($kid, WNOHANG);

		# We exit on either successfully waiting for the kid, or
		# on errors.

		last if $tmp == $kid;
		last if $tmp == -1;

		select(undef, undef, undef, 0.05);

		if ($i > 1) {
			kill($i<6 ? 'TERM' : 'KILL', $kid);
		}
	}
}

1;
