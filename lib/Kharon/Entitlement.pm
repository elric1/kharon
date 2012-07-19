#
# The Entitlement hierarchy allows for an extensible entitlement check
# architecture for "simple" entitlements checks.

package Kharon::Entitlement;
use base qw(Kharon);

use strict;
use warnings;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = {
		    credlist => undef
		   };

	$self->{credlist} = $args{credlist} if defined($args{credlist});

	bless($self, $class);
	return $self;
}

#
# Set a list of credentials to be used for subsequent entitlements checks.
#
# Args:
#	@credlist	List of credentials to set
sub set_creds {
	my $self = shift;

	@{$self->{credlist}} = @_;
}

#
# Set options that affect the behaviour of the object.

sub set_opt {
	my ($self, $opt, $val) = @_;

	if ($opt eq 'throw') {
		# XXXrcd: ensure that $val is either 0 or 1.

		$self->{throw} = $val;
	} else {
		# XXXrcd: probably shouldn't just die but rather do something
		#         with the error class or something...
		die "set_opt: $opt is not a valid option.";
	}
}

#
# Throw an error when permission is denied.  This is expected to be
# over-ridden by child modules to fit in with their error handling
# schemes.

sub throw_eperm {
	my ($self, $msg) = @_;

	die [502, $msg];
}

#
# Check an entitlement.
#
# This is the method that we expect child classes to over-ride when
# defining the entitlements.  It takes as arguments the name of the
# entitlement and any associated arguments that are passed to it.  We
# generally refer to the entitlement as a ``verb''.
#
# Args:
#	$verb		Entitlement to check
#	@predicate	The remaining arguments.
#
# The return value of check1 can be undef meaning ``no comment''
# (this will generally be converted into deny but is useful for
# stacking entitlement objects), 0 meaning permission denied, 1
# meaning allowed or a textual message which means permission denied
# with the textual message being an error string.  You cannot have
# a textual error string which is either 0 or 1.
#
# XXXrcd: should we allow an object or reference to be returned which
#         will simply be thrown if $self->{throw} is defined?
#
sub check1 {
	# The base class fails closed
	return 0;
}

#
# Check an entitlement.
#
# Args:
#	$verb		Entitlement to check
#	@predicate	The remaining arguments.
#
# The return value is 0 for permission denied or 1 for allowed.
#
# This will generally not be overridden by subclasses as it implements
# class specific behaviour.  The results of check1 are converted into
# a strict boolean and if the throw option is set an error message is
# thrown by calling the method throw_eperm.
#
sub check {
	my ($self, $verb, @predicate) = @_;

	my $ret = $self->check1($verb, @predicate);

	$ret = 0 if !defined($ret);

	if ($ret ne '1' && $self->{throw}) {
		if ($ret eq '0') {
			$ret = "Permission denied.";
		}
		$self->throw_eperm($ret);
	}

	return $ret eq '1' ? 1 : 0;
}

1;
