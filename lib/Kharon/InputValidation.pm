#
# The InputValidation hierarchy allows for extensible input checks.

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

	return ();
}

1;
