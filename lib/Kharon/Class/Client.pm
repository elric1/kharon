# Blame: "Roland C. Dowdeswell" <elric@imrryr.org>

package Kharon::Class::Client;
use base qw(Kharon);

use Kharon::utils qw/getclassvar/;

use strict;
use warnings;

our $AUTOLOAD;

sub new {
	my ($proto, $opts, @servers) = @_;
	my $class = ref($proto) || $proto;

	die "This is a virtual method [for now]";
}

sub DESTROY {}

sub AUTOLOAD {
	my ($self, @args) = @_;
	my $class = ref($self);

	if (!defined($class)) {
		die "Not an object...";	# XXXrcd: really shouldn't happen.
	}

	my $method = $AUTOLOAD;
	$method =~ s/.*://o;

	_runfunc($method, $self, @args);
}

sub _runfunc {
	my ($method, $self, @args) = @_;
	my $class = ref($self);

	my @rosccmds = getclassvar($self, "KHARON_RO_SC_EXPORT");
	my @roaccmds = getclassvar($self, "KHARON_RO_AC_EXPORT");
	my @rwsccmds = getclassvar($self, "KHARON_RW_SC_EXPORT");
	my @rwaccmds = getclassvar($self, "KHARON_RW_AC_EXPORT");

	my $ac;
	$ac = 1	if grep { $_ eq $method } (@roaccmds, @rwaccmds);
	$ac = 0 if grep { $_ eq $method } (@rosccmds, @rwsccmds);

	if (!defined($ac)) {
		die "Undefined method $method called in $class";
	}

	my @ret = $self->{pec}->CommandExc($method, @args);

	if ($ac == 1) {
		return @ret;
	}

	if (scalar(@ret) > 1) {
		throw Kharon::PermanentError("Kharon scalar method " .
		    "\"$method\" returned a list", 500);
	}

	return          if !defined(wantarray());
	return ()       if @ret == 0 && wantarray();
	return undef    if @ret == 0;
	return $ret[0];
}

sub can {
	my ($self, $method) = @_;

	my @kharon_exports = qw/KHARON_RO_SC_EXPORT KHARON_RW_SC_EXPORT
				KHARON_RO_AC_EXPORT KHARON_RW_AC_EXPORT/;

	my @cmds = map { getclassvar($self, $_) } @kharon_exports;

	if (grep { $method eq $_ } @cmds) {
		return sub { _runfunc($method, @_) };
	}

	return $self->SUPER::can($method);
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
