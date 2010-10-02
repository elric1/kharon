#
# PermanentError
#
# Exception class for permanent (non-retriable 5xx errors)

package Kharon::PermanentError;
use base qw(Kharon::KharonError);

use warnings;
use strict;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(@_);

	bless($self, $class);
	return $self;
}

1;
