#
# The InputValidation hierarchy allows for extensible input checks.
#
# Kharon::InputValidation objects are expected to inherit from this
# object and override validate().  Each time a method is called,
# validate() will be called with: $self, $verb, @args.  If the input
# is to be rejected, an exception should be thrown describing why the
# input fails to be valid.  If the input is acceptable, undef should
# be returned.  To change the input to the underlying function, return
# an array ref containing the new argument list.

package Kharon::InputValidation;
use base qw(Kharon);

use Exporter qw/import/;
@EXPORT_OK = qw{
	KHARON_IV_NO_ARGS
	KHARON_IV_ONE_SCALAR
};

use strict;
use warnings;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = {};

	bless($self, $class);
	return $self;
}

sub validate {
	# Base class doesn't modify input parameters

	return undef;
}

#
# Shared utility functions:

sub KHARON_IV_NO_ARGS {
	my ($self, $verb, @args) = @_;

	my $usage = "$verb";

	if (@args) {
		die [503, "Syntax error: too many args\n$usage"];
	}

	return undef;
}

sub KHARON_IV_ONE_SCALAR {
	my ($self, $verb, @args) = @_;

	my $usage = "$verb <arg>";

	if (@args < 1) {
		die [503, "Syntax error: no args\nusage: $usage"];
	}

	if (@args > 1) {
		die [503, "Syntax error: too many  args\nusage: $usage"];
	}

	if (ref($args[0]) ne '') {
		die [503, "Syntax error: arg 1 not a scalar\nusage: $usage"];
	}

	return undef;
}

1;
