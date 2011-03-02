#
# ProtocolEngineServerStd
#
# Client and Server base class for read/write ops on stdin/stdout

package Kharon::Engine::Std;

use base qw/Kharon::Engine/;

use Kharon::TransientError qw(:try);
use Kharon::PermanentError qw(:try);

use warnings;
use strict;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(@_);

	$self->{NAME} = "STDIN/STDOUT Engine BASE";

	bless ($self, $class);
	return $self;
}

sub Connect {
	my $self = shift;

	$self->{in}  = \*STDIN;
	$self->{out} = \*STDOUT;

	return 1;
}

sub Disconnect {
	my $self = shift;

	close($self->{in});
	close($self->{out});

	$self->{in}  = undef;
	$self->{out} = undef;

	return 1;
}

sub Read {
	my ($self) = @_;
	my $buf;

	my $ret = sysread($self->{in}, $buf, 32768);

	return undef if !defined($ret) || $ret == 0;
	return $buf;
}

sub Write {
	my $self = shift;

	print {$self->{out}} @_;
	$self->{out}->flush();

	return 1;
}

1;
