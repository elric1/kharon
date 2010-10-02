#
# Engine
#
# Base class for ProtocolEngineServer and ProtocolEngine client.

package Kharon::Engine;

use Carp;
use Kharon::Log::Syslog;

use warnings;
use strict;

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my @protolist = @{$args{protocols}};
# XXX:	@protolist = (Kharon::Response->new()) if scalar(@protolist) == 0;

	my $self = {
		    in		=> undef,	# input file descriptor
		    out		=> undef,	# output file descriptor

		    protolist	=> \@protolist,	# list of protocols...
		    resp	=> undef,	# Response-derived object ref

		    NAME	=> undef,
		    DESCR	=> undef,

		    logger	=> Kharon::Log::Syslog->new(),
		   };

	$self->{resp} = $self->{protolist}->[0];

	bless ($self, $class);
}

sub set_logger {
	my ($self, $logger) = @_;

	$self->{logger} = $logger;
}

sub Read {
	confess("Abstract implementation invoked.");
}

sub Write {
	confess("Abstract implementation invoked.");
}

1;
