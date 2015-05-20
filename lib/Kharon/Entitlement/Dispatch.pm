#
# This one will take a list of URL-like things and return true if
# creds match one of them.

#
# We're going to work on either Kharon::Entitlement objects or simple code
# refs.  We'll let the users decide which one is the easiest to use...

package Kharon::Entitlement::Dispatch;
use base qw(Kharon::Entitlement);

use IO::File;

use Kharon::utils;

use warnings;
use strict;

#
# We start with the methods:

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(%args);
	$self->{handlers} = {};

	bless($self, $class);

	if (exists($args{handlers}) && defined($args{handlers})) {
		if (ref($args{handlers}) ne 'ARRAY') {
			# XXXrcd: better error needed!
			die "handlers must be an ARRAY ref";
		}

		$self->register_handlers(@{$args{handlers}});
	}

	return $self;
}

sub check1 {
	my ($self, $ent) = @_;
	my $handlers = $self->{handlers};

	my ($scheme, $subent) = split(/:\/\//, $ent, 2);
	if (!defined($scheme) || !defined($subent)) {
		Kharon::utils::logger "Malformed group: $ent";
		return 0;
	}

	my $handler = $handlers->{$scheme};
	if (!defined($handler)) {
		Kharon::utils::logger "No handler registered for " .
		    "scheme $scheme";
		return 0;
	}

	# First success means overall success:

	if (ref($handler) eq 'CODE') {
		for my $cred (@{$self->{credlist}}) {
			if (&{$handler}($cred, $subent)) {
				return 1;
			}
		}
	}

	if ($handler->isa('Kharon::Entitlement')) {
		if ($handler->check($subent)) {
			return 1;
		}
	}

	# No handler claimed there was a match
	return 0;
}

sub set_creds {
	my ($self, @creds) = @_;
	my $handlers = $self->{handlers};

	for my $scheme (keys %$handlers) {
		my $handler = $handlers->{$scheme};

		if ($handler->isa('Kharon::Entitlement')) {
			$handler->set_creds(@creds);
		}
	}
	return $self->SUPER::set_creds(@creds);
}

#
# Object methods that are specific to Kharon::Dispatch.pm:

sub register_handler {
	my ($self, $scheme, $handler) = @_;
	my $handlers = $self->{handlers};

	if (ref($handler) ne 'CODE' && !$handler->isa('Kharon::Entitlement')) {
		die "Woah, bad handler type.  Gotta be a code ref or an " .
		    "Kharon::Entitlement";
	}

	$handlers->{$scheme} = $handler;

	$handler->set_creds(@{$self->{credlist}});
}

#
#
# This one takes a list of list refs each of which is passed to
# register_handler...  It's mostly for our constructor.

sub register_handlers {
	my ($self, @handlers) = @_;

	for my $h (@handlers) {
		$self->register_handler(@$h);
	}
}

sub list_handlers {
	my ($self) = @_;
	my $handlers = $self->{handlers};

	print "URI Schemes Registered\n";
	print "-------------------------------------------------------------\n";
	for my $scheme (keys %$handlers) {
		printf("%- 20.20s %s\n", "$scheme://",
		    ref($handlers->{$scheme}));
	}
}

1;
