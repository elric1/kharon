#
# Implement an Kharon::InputValidation that takes an object and will invoke
# methods in it to validate the input.  Kharon::InputValidation::Object
# when called will look for methods of the form KHARON_IV_<verb>.  They
# are expected to have the same input and output as any validate method
# in the Kharon::InputValidation framework.

package Kharon::InputValidation::Object;
use base qw(Kharon::InputValidation);

use warnings;
use strict;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(%args);

	$self->{subobject} = $args{subobject};

	return $self;
}

sub set_subobject {
	my ($self, $subobject) = @_;

	$self->{subobject} = $subobject;
}

sub validate {
	my ($self, $verb, @args) = @_;
	my $subobj = $self->{subobject};
	my $f;

	$f = $subobj->can("KHARON_IV_$verb");
	if (defined($f)) {
		return &$f($subobj, $verb, @args);
	}

	return undef;
}

1;
