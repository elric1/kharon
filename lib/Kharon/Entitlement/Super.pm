#
# Implement a ACL superclass which can be inherited by subclasses that
# want to use a bit of OO to define the ACLs.
#

package Kharon::Entitlement::Super
use base qw(Kharon::Entitlement);

use warnings;
use strict;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(%args);

	bless($self, $class);
	return $self;
}

sub check1 {
	my ($self, $verb, @args) = @_;

	#
	# In this module, we assume that we are simply inherited by
	# a module that defines methods ACL_$verb which will take @args
	# and return whether the entitlement passes.

	my $acl = $self->can("ACL_$verb");

	if (defined($acl)) {
		return $acl($self, @args);
	}

	return 0;
}

1;
