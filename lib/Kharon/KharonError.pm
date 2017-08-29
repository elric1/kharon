#
# Base Error
#
# Exception class

#
# TODO: Allow error tables -- this gives us consistent, non-overlapping
# numeric code spaces with consistent (localizable!) error messages.

package Kharon::KharonError;
use base qw(Error);
use Error;
use warnings;
use strict;

sub new {
	(my $proto, my $text, my $code) = @_;

	my $class = ref($proto) || $proto;
	my $self = $class->SUPER::new(-text => "$text\n");

	$self->{CODE} = $code;		# Protocol return code

	bless($self, $class);
	return $self;
}

sub CODE {
	my $self = shift;

	return $self->{CODE};
}

# Args:
#	Text of error to chain
#	(optional) new error code
sub chain {
	(my $self, my $text, my $code) = @_;

	$self->{-text} = $text . ",\n  because (" . $self->{CODE} .
	  ") " . $self->{-text};

	if (defined($code)) {
		$self->{CODE} = $code;
	}

	return $self;
}
1;
