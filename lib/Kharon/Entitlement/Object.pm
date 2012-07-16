#
# Implement an ACL that takes an object and will invoke methods in it
# to return the entitlement status.  Kharon::Entitlement::Object when
# called will look for methods of the form KHARON_COMMON_ACL and
# KHARON_ACL_<verb>.  It will first invoke KHARON_COMMON_ACL giving
# it the arguments ($verb, @args).  If this returns a defined value,
# it will be used as the entitlement status.  If not, then it will
# invoke KHARON_ACL_<verb> in the same way.  If this is not found,
# then it will return 0 (Permission denied).

package Kharon::Entitlement::Object;
use base qw(Kharon::Entitlement);

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
	$self->set_creds(@{$self->{credlist}});
}

sub set_creds {
	my ($self, @creds) = @_;
	my $subobj = $self->{subobject};

	$self->SUPER::set_creds(@creds);

	return if !defined($subobj);

	my $f = $subobj->can('KHARON_SET_CREDS');
	if (!defined($f)) {
		die "Entitlement subobject does not implement method set_creds";
	}

	return &$f($subobj, @creds);
}

sub check1 {
	my ($self, $verb, @args) = @_;
	my $subobj = $self->{subobject};
	my $acl;

	$acl = $subobj->can("KHARON_COMMON_ACL");
	if (defined($acl)) {
		my $ret = &$acl($subobj, $verb, @args);

		if (defined($ret)) {
			return $ret;
		}
	}

	$acl = $subobj->can("KHARON_ACL_$verb");
	if (defined($acl)) {
		return &$acl($subobj, $verb, @args);
	}

	return 0;
}

1;
