package Khaorn::Entitlement::Equals;
use base qw(Khaorn::Entitlement);

use strict;
use warnings;

sub check1 {
	my ($self, $ent) = @_;

	for my $cred (@{$self->{credlist}}) {
		return 1 if $cred eq $ent;
	}

	return 0;
}

1;
