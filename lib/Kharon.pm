package Kharon;

use version 0.77;

our $VERSION = version->declare("v0.2");

use warnings;
use strict;

sub VERSION {
	my ($self, $required) = @_;

	return $VERSION	if !defined($required);

	my $me  = version->parse($VERSION);
	my $req = version->parse($required);

	if ($me < $req) {
		die "Kharon version $req required--this is only version $me";
	}

	return $VERSION;
}

1;

__END__

=head1 NAME

Kharon - a client/server application development framework

=head1 VERSION

Version 0.01

=cut


=head1 SYNOPSIS

Kharon is an OO RPC framework which can be used to quickly write
client/server applications.

=head1 AUTHOR

Roland C. Dowdeswell, C<< <elric at imrryr.org> >>
