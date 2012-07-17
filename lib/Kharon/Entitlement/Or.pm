#
# This entitlement allows one to evaluate a list of entitlements returning
# true if any of them evaluate to true.  The list is evaluated in order but
# the result is [obviously] independent of order.

package Kharon::Entitlement::Or;
use base qw(Kharon::Entitlement::List);

use warnings;
use strict;

sub check1 {
	my ($self, @args) = @_;
	my $subobjs = $self->{subobjects};
	my $ret;
	my %errs;

	for my $obj (@$subobjs) {
		eval { $ret = $obj->check(@args); };

		return 1 if defined($ret) && $ret eq '1';

		$errs{$@->[1]} = 1	if $@;
	}

	delete $errs{"Permission denied."};

	return join(', ', keys %errs)	if keys %errs > 0;
	return 0;
}

1;
