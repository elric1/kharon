package Kharon::Entitlement::Client;
use base qw(Kharon::Entitlement);

use Kharon::Engine::Client::Net;

use warnings;
use strict;

#
# We start with the methods:

sub new {
	my ($proto, %args) = @_;
	my $class = ref($proto) || $proto;

	my $self = $class->SUPER::new(%args);

        my $ahr = Kharon::Protocol::ArrayHash->new(banner => {version=>'1.0'});
	my $pec = Kharon::Engine::Client::UNIX->new($ahr);
        $pec->Connect($args{servers});

	bless($self, $class);
	return $self;
}

eval mk_scalar_methods('Kharon::Entitlement', qw/check1 set_creds/);

1;
