package Kharon::Entitlement::Equals;
use base qw(Kharon::Entitlement);

use strict;
use warnings;

sub check1 {
	my ($self, @ents) = @_;

	for my $cred (@{$self->{credlist}}) {
		for my $ent (@ents) {
			return 1 if $ent eq $cred;
		}
	}

	return undef;
}

1;
