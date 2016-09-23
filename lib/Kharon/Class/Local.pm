# Blame: "Roland C. Dowdeswell" <elric@imrryr.org>

package Kharon::Class::Local;
use base qw(Kharon);

use Sys::Hostname;

use Kharon::Class::LC;
use Kharon::utils qw/getclassvar/;

use strict;
use warnings;

our $AUTOLOAD;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = {};

	$self->{obj} = $args{obj};
	$self->{iv}  = $args{iv};

	return bless($self, $class);
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
	my $obj   = $self->{obj};
	my $iv    = $self->{iv};

	my $rw = Kharon::Class::LC::is_rw_method($obj, $method);

	if (!defined($rw)) {
		die "Undefined method $method called in $class";
	}

	if ($rw) {
		my $master;
		eval { $master = $obj->KHARON_MASTER(); };

		if (defined($master) && $master ne hostname()) {
			die [500, "In local mode, rw commands must be issued ".
			    "on the master: $master"];
		}
	}

	if (defined($iv)) {
		my $new_args2;

		$new_args2 = $iv->validate($method, @args);

		@args = @$new_args2 if defined($new_args2);
	}

	return $obj->$method(@args);
}

sub can {
	my ($self, $method) = @_;

	return sub {_runfunc($method, @_)} if Kharon::Class::LC::my_can(@_);
	return $self->SUPER::can($method);
}

1;

__END__

=head1 NAME

Kharon::Class::Local - base class for Kharon clients operating locally

=head1 SYNOPSIS

use base qw(Kharon::Class::Client);

=head1 DESCRIPTION

Kharon::Class::Local is a separate class which can be used to
implement a Kharon client operating locally.  The main difference
between using this class and just directly calling the object is
that input validation can be defined.  In normal usage, a specific
local client class will be written which uses it.  Kharon::Class::Local
expects the following class variables to be defined:

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
