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
	my $self = shift;

	# XXXrcd: check for errors.
#	readline $self->{in};
my $ret;
my $out = sysread($self->{in}, $ret, 65536);
# print STDERR "$out chars read: '$ret'\n";
$ret;
}

sub Write {
	my $self = shift;

	print {$self->{out}} @_;
	$self->{out}->flush();

	return 1;
}

1;
