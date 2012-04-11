package Kharon::Test::TestObjFork;

use Kharon::Protocol::ArrayHash;
use Kharon::Engine::Server;
use Kharon::Engine::Client::Fork;
use Kharon::utils qw/mk_array_methods mk_scalar_methods/;

use POSIX;

use Kharon::Test::TestObj;

use strict;
use warnings;

sub run_daemon {
	my ($fh) = @_;

	dup2($fh->fileno(), 0);
	dup2($fh->fileno(), 1);

	my $obj = Kharon::Test::TestObj->new();
	my $ahr = Kharon::Protocol::ArrayHash->new(banner => {version=>'2.0'});
	my $pes = Kharon::Engine::Server->new(protocols => [ $ahr ]);
	$pes->Connect();

	$pes->RunObj(
		object => $obj,
		cmds => [ qw/inc query exception complicated uniq encapsulate
			     retnothing/ ]
	);
	exit(0);
}

sub new {
	my ($isa, @servers) = @_;
	my $self;

	my $ahr = Kharon::Protocol::ArrayHash->new(banner => {version=>'2.0'});
	my $pec = Kharon::Engine::Client::Fork->new(protocols => [$ahr]);

	my ($kid, $fh) = $pec->Connect();

	run_daemon($fh) if $kid == 0;

	$self->{pec} = $pec;
	$self->{kid} = $kid;

	bless($self, $isa);
}

eval mk_scalar_methods('Kharon::Test::TestObj',
    qw/inc query exception retnothing/);
eval mk_array_methods('Kharon::Test::TestObj',
    qw/complicated uniq encapsulate/);

1;
