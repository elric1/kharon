#
# Provides a protocol class which forms the basis for the communication.


package Kharon::Protocol::Base;
use Kharon::utils qw/get_next_word/;

use warnings;
use strict;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;
	my $self = {
		    CODE		=> undef,	# Response code
		    RESULTS		=> undef,	# List of text lines
		    					# raw, from "wire"
		    more		=> 1,		# Zero when we've seen
		    					# "."
		    banner		=> $args{banner},
		   };

	bless ($self, $class);
	return $self;
}

sub bannerMatches {
	my ($self, $banner) = @_;

	$self->{banner} eq $banner;
}

sub code {
	my $self = shift;
	if (@_) { $self->{CODE} = shift; }

	return $self->{CODE};
}

sub results {
	my $self = shift;

	return @{$self->{RESULTS}};
}

sub getguts {
	my ($self) = @_;

	($self->{CODE}, $self->{more}, @{$self->{RESULTS}});
}

sub setguts {
	my ($self, $code, $more, @results) = @_;

	$self->{CODE}    = $code;
	$self->{more}    = $more;
	$self->{RESULTS} = \@results;
}

sub append {
	my ($self, @lines) = @_;

	for my $line (@lines) {
		my ($code, $dotdash, $result) =
		 ($line =~ /^([0-9][0-9][0-9]) *([-.]) *([^\r\n]*)(\r\n|\n)$/o);

		return undef			    if !defined($1);
		die "Continued after end in append" if $self->{more} == 0;

		# XXXrcd: we should deal with inconsistent CODEs in some
		#         better way.  I.e. what if we toss an exception
		#         half way through dealing with a multipart response
		#         after we've already sent the client some of the
		#         return values.  Probably we just raise it at the
		#         same point as the server did...

		if (defined($self->{CODE}) && $self->{CODE} != $code) {
			die "Server returned inconsistent code.";
		}

		$self->{CODE} = $code;
		push(@{$self->{RESULTS}}, $result);

		if ($dotdash eq '.') {
			$self->{more} = 0;
			last;
		}
	}

	$self->{more};
}

sub Reset {
	my $self = shift;

	$self->{CODE} = undef;
	@{$self->{RESULTS}} = ();
	$self->{more} = 1;
}

sub SendBanner {
	my ($self) = @_;

	$self->{banner};
}

sub Parse {
	my $self = shift;

	return ($self->{CODE}, @{$self->{RESULTS}});
}

#
# Encode a line based response...
# This does not escape the contents of $line.  It is expected that
# the caller do the escaping.  This is so that we can avoid multiple
# layers of escaping in the code.  This is potentially suboptimal.
# XXXrcd: should we assume that \r\n are escaped or check?
#
# Args:
#	$code		The response code (prefixed to all lines)
#	@resplist	List of lines.
#
# Returns
#	A list of encoded lines ready for transmission
sub Encode {
	my ($self, $code, @lines) = @_;

	my @result = map { "$code - $_\r\n" } @lines;
	if ($#lines == -1) {
		@lines = ('');
	}
	$result[$#lines] = "$code . " . $lines[$#lines] . "\r\n";
	@result;
}

#
# Encode an error response
#
# We toss an exception.  This is a virtual function...
sub Encode_Error {
	my ($self, $code, $str) = @_;

# XXXrcd: fix this to be a real error message...
	die "Calling a virtual function";
}

#
# Marshall a field
#
# This is a NOP for the base Response object
#
sub Marshall {
	my ($self, $string) = @_;

	return "$string\r\n"			if ref($string) eq '';
	return join(' ', @$string) . "\r\n"	if ref($string) eq 'ARRAY';
}

#
# Unmarshall a field
#
# Basically, return ($command, $rest_of_line)
#
sub Unmarshall {
	my ($self, $line) = @_;

	get_next_word($line);
}

1;
