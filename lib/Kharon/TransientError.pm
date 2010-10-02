#
# TransientError
#
# Exception class for transient (retriable 4xx errors)

package Kharon::TransientError;
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
