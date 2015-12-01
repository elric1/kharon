#
# The InputValidation hierarchy allows for extensible input checks.
#
# Kharon::InputValidation objects are expected to inherit from this
# object and override validate().  Each time a method is called,
# validate() will be called with: $self, $verb, @args.  If the input
# is to be rejected, an exception should be thrown describing why the
# input fails to be valid.  If the input is acceptable, undef should
# be returned.  To change the input to the underlying function, return
# an array ref containing the new argument list.

package Kharon::InputValidation;
use base qw(Kharon);

use strict;
use warnings;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = {};

	bless($self, $class);
	return $self;
}

sub validate {
	# Base class doesn't modify input parameters

	return undef;
}

1;
