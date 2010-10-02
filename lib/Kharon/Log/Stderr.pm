package Kharon::Log::Stderr;

use base qw(Kharon::Log::Base);

use warnings;
use strict;

sub output_log {
	my ($self, $level, @args) = @_;

	for my $i (@args) {
		print STDERR "$i\n";
	}
}

1;
