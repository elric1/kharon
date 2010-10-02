package Kharon::Log::Syslog;

use Sys::Syslog;

use base qw(Kharon::Log::Base);

use warnings;
use strict;

sub output_log {
	my ($self, $level, @args) = @_;

	for my $i (@args) {
		syslog($level, "%s", $i);
	}
}

1;
