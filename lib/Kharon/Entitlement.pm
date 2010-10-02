#
# The Entitlement hierarchy allows for an extensible entitlement check
# architecture for "simple" entitlements checks.

package Kharon::Entitlement;

use strict;
use warnings;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = {
		    credlist => undef
		   };

	$self->{credlist} = $args{credlist} if defined($args{credlist});

	bless($self, $class);
	return $self;
}

#
# Set a list of credentials to be used for subsequent entitlements checks.
#
# Args:
#	@credlist	List of credentials to set
sub set_creds {
	my $self = shift;

	@{$self->{credlist}} = @_;
}

#
# Check a single entitlement
#
# Args:
#	$ent		Entitlement to check
sub check1 {
	# The base class fails closed
	return 0;
}

#
# Check a list of entitlements returning true if any match.
#
# Args:
#	@ents		A list of entitlements to check
#
# This will generally not be overridden by subclasses unless
# there is a substantial performance benefit that can be achieved.
#
sub check {
	my ($self, @ents) = @_;

	for my $ent (@ents) {
		return 1 if ($self->check1($ent) == 1);
	}
	return 0;
}

1;
