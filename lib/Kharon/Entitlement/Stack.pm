#
# This entitlement allows one to evaluate a list of entitlements in order
# stopping when the first one returns a definitive result.

package Kharon::Entitlement::Stack;
use base qw(Kharon::Entitlement::List);

use warnings;
use strict;

sub check1 {
	my ($self, @args) = @_;
	my $subobjs = $self->{subobjects};
	my $ret;
	my %errs;

	for my $obj (@$subobjs) {
		eval { $ret = $obj->check1(@args); };

		# XXXrcd: we should likely log this error...

		return $ret if defined($ret);
	}

	return 0;
}

1;
