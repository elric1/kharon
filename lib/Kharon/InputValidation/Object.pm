#
# Implement an ACL that takes an object and will invoke methods in it
# to return the entitlement status.  Kharon::Entitlement::Object when
# called will look for methods of the form KHARON_COMMON_ACL and
# KHARON_ACL_<verb>.  It will first invoke KHARON_COMMON_ACL giving
# it the arguments ($verb, @args).  If this returns a defined value,
# it will be used as the entitlement status.  If not, then it will
# invoke KHARON_ACL_<verb> in the same way.  If this is not found,
# then it will return 0 (Permission denied).

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

	return ();
}

1;
