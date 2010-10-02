#
# ProtocolEngineClientCmd
#
# Client base class, performs read/write operations on file descriptors
# connected to a command

package Kharon::Engine::Client::Cmd;

use IPC::Open2;
use NEXT;
use POSIX;

use base qw/Kharon::Engine::Client::Fork/;

use Kharon::TransientError qw(:try);
use Kharon::PermanentError qw(:try);

use strict;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = $class->NEXT::new(@_);

	$self->{NAME} = "STDIN/STDOUT Client Engine";

	bless ($self, $class);
	return $self;
}

sub Connect {
	my ($self, @cmd) = @_;
	my $logger = $self->{logger};

	$logger->log('debug', "executing " . join(" ", @cmd) . "\n");

	my ($kid, $fh) = $self->SUPER::Connect();
	$self->{kid} = $kid;
	return 1 if $kid > 0;

	dup2($fh->fileno(), 0);
	dup2($fh->fileno(), 1);

	exec { $cmd[0] } @cmd;
	die "exec failed: $!";
}

1;
