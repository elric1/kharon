#
# Protocol class capable of parsing nested perl data structures including
# list refs, hash refs, scalars and undef.

package Kharon::Protocol::ArrayHash;
use base qw(Kharon::Protocol::Base);
use Exporter;

# use Parse::Parse;

use Time::HiRes qw(gettimeofday tv_interval);

use Kharon::utils qw{encode_var tokenise};

use warnings;
use strict;

sub new {
	my ($proto, @args) = @_;
	my $class = ref($proto) || $proto;
	my %hash = @args;

	my $self = $class->SUPER::new(@args);

#	$self->{parse} = Parse::new();

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

#sub Reset {
#	my ($self) = @_;
#
#	$self->{more} = 1;
#	$self->{RESULTS} = [];
##	$self->{parse} = Parse::new();
#}

#sub append {
#	my ($self, @lines) = @_;
#
## XXXrcd: hackery!
#
#	for my $line (@lines) {
#		my $ret = $self->{parse}->parse($line);
#
## print STDERR "Parsing line '$line'\n";
#		if (ref($ret) eq 'ARRAY') {
## print STDERR "Setting result set $ret, length = " . scalar(@$ret) . "\n";
#			$self->{RESULTS} = $ret;
#			$self->{more} = 0;
#		}
#	}
#
#	$self->{more};
#}

sub Parse {
	my ($self) = @_;
	my ($code, @plist) = $self->SUPER::Parse();
#	my $parser = Parse::new();

#	my $ret;
#	for my $i (@plist) {
#		$ret = $parser->parse($i);
#	}
#	return ($code, $ret);

#	return (200, @{$self->{RESULTS}});

#        return ($code, @{Parse::tokenise(join(' ', @plist) . "\r\n")});
#        return ($code, @{Parse::tokenise2(join(' ', @plist) . "\r\n")});

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

#	return $self->SUPER::Encode($code, map {Parse::encode_var($_)} @vars);
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

#	my $str = join(' ', map {Parse::encode_var($_)} @$cmd);
	my $str = join(' ', map {encode_var($_, '[ ]', 'OUTER')} @$cmd);
	$self->SUPER::Marshall($str);
}

sub Unmarshall {
	my ($self, $line) = @_;

#	Parse::tokenise($line . "\r\n");
	tokenise([$line]);
}

1;
