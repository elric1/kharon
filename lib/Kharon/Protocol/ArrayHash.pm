#
# Protocol class capable of parsing nested perl data structures including
# list refs, hash refs, scalars and undef.

package Kharon::Protocol::ArrayHash;
use base qw(Kharon::Protocol::Base);
use Exporter;

use Time::HiRes qw(gettimeofday tv_interval);

use Kharon::utils qw{encode_var tokenise};

use warnings;
use strict;

sub new {
	my ($proto, @args) = @_;
	my $class = ref($proto) || $proto;
	my %hash = @args;

	my $self = $class->SUPER::new(@args);

	bless($self, $class);
	return $self;
}

sub bannerMatches {
	my ($self, $banner) = @_;

	if (ref($banner) eq 'HASH') {
		for my $i (keys %{$self->{$banner}}) {
			return 0 if !exists($banner->{$i});
			return 0 if $self->{$banner}->{$i} ne $banner->{$i};
		}
		return 1;
	}

	0;
}

sub Parse {
	my ($self) = @_;
	my ($code, @plist) = $self->SUPER::Parse();

	($code, tokenise([shift(@plist), map {" $_"} @plist]));
}

#
# Emit a sequence of ArrayHash rows.
#
# Args:
#	$code	The response code (prefixed to all lines)
#	@vars	List of hashrefs to individual rows of the response
sub Encode {
	my ($self, $code, @vars) = @_;

	$self->SUPER::Encode($code, map {encode_var($_, '[ ]', 'OUTER')} @vars);
}


#
# Encode an error response
#
# This special case subroutine lets us return errors without understanding
# the additional layers of semantics which may be imposed on the protocol
# fields.  It supports a single, simple error text string.
#
# Args:
#	$code		The error response code (prefixed to all lines)
#	$errstring	The text of the error message.
sub Encode_Error {
	my ($self, $code, $str) = @_;

	return $self->Encode($code, { errstr => $str });
}

sub Marshall {
	my ($self, $cmd) = @_;

# XXXrcd: check to ensure that first element of $cmd is a scalar.

	my $str = join(' ', map {encode_var($_, '[ ]', 'OUTER')} @$cmd);
	$self->SUPER::Marshall($str);
}

sub Unmarshall {
	my ($self, $line) = @_;

	tokenise([$line]);
}

1;
