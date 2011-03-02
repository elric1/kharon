#
# ProtocolEngineClient
#
# Client base class, performs read/write operations on stdin/stdout.

package Kharon::Engine::Client;

use base qw/Kharon::Engine::Std/;

use Kharon::Log::Stderr;

use Kharon::TransientError qw(:try);
use Kharon::PermanentError qw(:try);

use warnings;
use strict;

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(@_);

	$self->{logger} = Kharon::Log::Stderr->new();
	$self->{NAME} = "STDIN/STDOUT Client Engine";

	bless ($self, $class);
	return $self;
}

sub Connect {
	my ($self) = @_;
	my $logger = $self->{logger};

	#
	# We do not override in and out if a superclass has already
	# defined it.

	$self->{in}  = \*STDIN		if !defined($self->{in});
	$self->{out} = \*STDOUT		if !defined($self->{out});

	#
	# But we do unconditionally read the banner if our protocol
	# object defines that we have a banner.  We simply check if
	# the protocol object defines ``SendBanner'' and if returns
	# something because that's what the server side will use to
	# decide whether to send one.

	my $oldproto;
	for my $proto (@{$self->{protolist}}) {
		$self->{resp} = $proto;
		my $send = $proto->can('SendBanner');
		if (!defined($send) || !defined(&$send($proto))) {
			# no banner parsing---we assume that this is the
			# terminal protocol as we have no way to check if
			# it's valid:

			return 1;
		}

		my ($code, $banner);
		if (defined($oldproto)) {
			$proto->setguts($oldproto->getguts());
			($code, my $ret) = $proto->Parse();
			($banner) = @$ret;
		} else {
			($code, $banner) = $self->CommandResult();
		}

                $logger->log('debug', "Trying protocol $proto");

		return 1 if $proto->bannerMatches($banner);
                $logger->log('debug', "Protocol $oldproto didn't match");

		$oldproto = $proto;
	}
	0;
}

sub GetBanner { $_[0]->{banner}; }

sub CommandExc {
	my ($self, $cmd, @args) = @_;

	my ($code, @result) = $self->Command([$cmd, @args]);

	die @result if ($code > 300);

	#
	# XXXrcd: hmmm.  Not good.
	if (@result == 1 && ! wantarray()) {
		return $result[0];
	}

	@result;
}

sub Command {
	my ($self, $cmd, $callback, $cookie) = @_;

	try {
		$self->Write($self->{resp}->Marshall($cmd));
	} catch Error with {
		shift->chain("Writing command")->throw;
	};

	$self->CommandResult($cmd, $callback, $cookie);
}

sub CommandResult {
	my ($self, $cmd, $callback, $cookie) = @_;
	my @response;
	my $code;
	my $str;
	my $ret;

	try {
		$self->{resp}->Reset();

		do {
			$str = $self->Read();
			if (!defined($str)) {
				throw Kharon::PermanentError("No response?",
				    500);
			}
			$ret = $self->{resp}->append($str);
		} while (defined($ret) && $ret == 1);

		if (!defined($ret)) {
			throw Kharon::PermanentError("Malformed response:" .
						  "[" . $str . "]", 500);
		}

		($code, my $ret) = $self->{resp}->Parse();
		@response = @$ret;
	} catch Kharon::KharonError with {
		shift->chain("Error reading command response")->throw;
	};

	#
	# First, let's see if we have been asked to move on.  We simply
	# hand the @response to our ReConnect() method under the assumption
	# that it will magically know what to do with the result...

	if ($code == 301 && $self->can('ReConnect')) {
		$self->ReConnect(@response);
		return $self->Command($cmd, $callback, $cookie);
	}

	#
	# XXXrcd: hack alert!
	for (my $i=0; $i < @response; $i++) {
		if (ref($response[$i]) eq 'CODE') {
			$response[$i] = &{$response[$i]}($self);
		}
	}

	# If we've been given a response callback, and we have a valid
	# response, send it to the callback for processing.  We also pass
	# verbatim the user-supplied "cookie".  This allows the caller
	# of this method to easily make use of the same response callback
	# for similar tasks.

	try {
		if (@response && defined($callback)) {
			$ret = &$callback($cmd, $cookie, $code, @response);
		}
	} catch Kharon::KharonError with {
		shift->chain("Callback reported failure")->throw;
	};

	if (@response && defined($callback)) {
		return $ret;
	} else {
		return ($code, @response);
	}
}

1;
