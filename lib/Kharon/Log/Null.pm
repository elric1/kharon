package Kharon::Log::Null;

use base qw(Kharon::Log::Base);

use warnings;
use strict;

sub output_log {
	my ($self, $level, @args) = @_;

}

1;
