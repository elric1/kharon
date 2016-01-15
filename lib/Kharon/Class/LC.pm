# Blame: "Roland C. Dowdeswell" <elric@imrryr.org>
#
# This class exists to share functionality between Kharon::Class::Client
# and Kharon::Class::Local.

package Kharon::Class::LC;
use base qw(Kharon);

use Kharon::utils qw/getclassvar/;

use strict;
use warnings;

sub is_ac_method {
	my ($self, $method) = @_;

	my @rosccmds = getclassvar($self, "KHARON_RO_SC_EXPORT");
	my @roaccmds = getclassvar($self, "KHARON_RO_AC_EXPORT");
	my @rwsccmds = getclassvar($self, "KHARON_RW_SC_EXPORT");
	my @rwaccmds = getclassvar($self, "KHARON_RW_AC_EXPORT");

	my $ac;
	$ac = 1	if grep { $_ eq $method } (@roaccmds, @rwaccmds);
	$ac = 0 if grep { $_ eq $method } (@rosccmds, @rwsccmds);

	return $ac;
}

sub my_can {
	my ($self, $method) = @_;

	my @kharon_exports = qw/KHARON_RO_SC_EXPORT KHARON_RW_SC_EXPORT
				KHARON_RO_AC_EXPORT KHARON_RW_AC_EXPORT/;

	my @cmds = map { getclassvar($self, $_) } @kharon_exports;

	if (grep { $method eq $_ } @cmds) {
		return 1;
	}

	return 0;
}

1;

__END__

=head1 NAME

Kharon::Engine::Client::Base - base class for Kharon clients

=head1 SYNOPSIS

use base qw(Kharon::Class::Client);

=head1 DESCRIPTION

Kharon::Class::Client is a superclass which can be used to implement
a Kharon client.  In normal usage, a specific client class will be
written which inherits it.  Kharon::Class::Client expects the following
class variables to be defined:

=over 8

=item @KHARON_RO_SC_EXPORT

The list of read-only scalar context methods.

=item @KHARON_RO_AC_EXPORT

The list of read-only array context methods.

=item @KHARON_RW_SC_EXPORT

The list of read/write scalar context methods.

=item @KHARON_RW_AC_EXPORT

The list of read/write array context methods.

=back

Kharon::Class::Client will use these arrays to automatically setup
methods of the same names.

Kharon::Class:Client does not provide a [working] constructor.
The class that inherits it is expected to provide a constructor
which initialises the Kharon connexion.  Kharon::Class::Client
expects $self to be a hash ref which contains a variable $self->{pec}
which is of type Kharon::Engine::Client.  When a method is called,
it will use $self->{pec} to contruct an RPC to a Kharon server.
