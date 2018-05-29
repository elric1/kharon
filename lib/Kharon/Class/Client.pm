# Blame: "Roland C. Dowdeswell" <elric@imrryr.org>

package Kharon::Class::Client;
use base qw(Kharon);

use Kharon::Class::LC;
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

	my $ac = Kharon::Class::LC::is_ac_method($self, $method);

	if (!defined($ac)) {
		die "Undefined method $method called in $class";
	}

	my @ret;
	eval { @ret = $self->{pec}->CommandExc($method, @args); };

	if (my $err = $@) {
		if ($self->can("KHARON_ENCAPSULATE_ERROR")) {
			$self->KHARON_ENCAPSULATE_ERROR($err);
		}

		die $err;
	}

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

	return sub {_runfunc($method, @_)} if Kharon::Class::LC::my_can(@_);
	return $self->SUPER::can($method);
}

sub KHARON_DEFAULT_ENCAPSULATE_ERROR {
	my ($self, $err) = @_;
	my $id = $self->KHARON_PEER();

	die $err				if !defined($id);
	die [$err->[0], "$id said: $err->[1]"]	if  ref($err) eq 'ARRAY'	&&
						    scalar(@$err) == 2		&&
						    ref($err->[0]) eq ''	&&
						    ref($err->[1]) eq '';
	die "$id said: $err"			if ref($err) eq '';
	die $err;
}

sub KHARON_PEER {
	my ($self) = @_;
	my $hr = $self->{pec}->{connexion};

	return $self->{pec}->{connexion}->{PeerAddr};
}

1;

__END__

=head1 NAME

Kharon::Class::Client - base class for Kharon clients

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
