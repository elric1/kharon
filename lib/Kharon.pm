package Kharon;

use version;

our $VERSION = version->new("v0.4");

use warnings;
use strict;

sub VERSION {
	my ($self, $required) = @_;

	return $VERSION	if !defined($required);

	my $req = version->new($required);

	if ($VERSION < $req) {
		die "Kharon version $req required--this is only version $VERSION";
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
