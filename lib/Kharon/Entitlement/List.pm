#
# This entitlement is used as a base class for entitlements that operate
# on a list of entitlements.  It's check routine throws an exception.

package Kharon::Entitlement::List;
use base qw(Kharon::Entitlement);

use UNIVERSAL qw(isa);

use warnings;
use strict;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(%args);
	$self->{subobjects} = [];

	if (exists($args{subobjects}) && defined($args{subobjects})) {
		if (ref($args{subobjects}) ne 'ARRAY') {
			# XXXrcd: better error needed!
			die "subobjects must be an ARRAY ref";
		}

		$self->set_subobjects(@{$args{subobjects}});
	}

	return $self;
}

sub set_creds {
	my ($self, @creds) = @_;
	my $subobjs = $self->{subobjects};

	for my $obj (@$subobjs) {
		$obj->set_creds(@creds);
	}
	return $self->SUPER::set_creds(@creds);
}

sub set_subobjects {
	my ($self, @subobjs) = @_;

	for my $obj (@subobjs) {
		if (!UNIVERSAL::isa($obj, 'Kharon::Entitlement')) {
			die "Woah, bad subobject passed.  Must be a " .
			    "Kharon::Entitlement";
		}
	}

	$self->{subobjects} = \@subobjs;

	# We don't want to catch errors...

	for my $obj (@subobjs) {
		$obj->set_opt('throw', 0);
	}

	$self->set_creds(@{$self->{credlist}});
}

sub check1 {
	my ($self, @args) = @_;

	die "Kharon::Entitlement::List does not implement check or check1";
}

1;
