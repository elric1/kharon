package Kharon::Test::TestObjFork;

use Kharon::InputValidation::Object;
use Kharon::Protocol::ArrayHash;
use Kharon::Engine::Server;
use Kharon::Engine::Client::Fork;
use Kharon::utils qw/mk_array_methods mk_scalar_methods/;

use POSIX;

use Kharon::Test::TestObj;

use strict;
use warnings;

sub run_daemon {
	my ($fh, $use_perl_parsing) = @_;

	dup2($fh->fileno(), 0);
	dup2($fh->fileno(), 1);

	my $obj = Kharon::Test::TestObj->new();
	my $ahr = make_ahr($use_perl_parsing);
	my $pes = Kharon::Engine::Server->new(protocols => [ $ahr ]);
	my $iv  = Kharon::InputValidation::Object->new(subobject => $obj);

	$pes->set_iv($iv);
	$pes->Connect();

	$pes->RunObj(
		object => $obj,
		cmds => [ qw/	inc
				query
				exception
				complicated
				uniq
				encapsulate
				ping_scalar
				ping_array
				ping_hash
				retnothing
				takes_one_hashref
			/ ]
	);
	exit(0);
}

sub make_ahr {
	my ($use_perl_parsing) = @_;

	my $banner = {version=>'2.0'};
	if ($use_perl_parsing) {
		return Kharon::Protocol::ArrayHashPerl->new(banner => $banner);
	} else {
		return Kharon::Protocol::ArrayHash->new(banner => $banner);
	}
}

sub new {
	my ($isa, $use_perl_parsing, @servers) = @_;
	my $self;

	my $ahr = make_ahr($use_perl_parsing);
	my $pec = Kharon::Engine::Client::Fork->new(protocols => [$ahr]);

	my ($kid, $fh) = $pec->Connect();

	run_daemon($fh, $use_perl_parsing) if $kid == 0;

	$self->{pec} = $pec;
	$self->{kid} = $kid;

	bless($self, $isa);
}

eval mk_scalar_methods(
	'Kharon::Test::TestObj',
	qw/	inc
		query
		exception
		ping_scalar
		retnothing
		takes_one_hashref
	/);
eval mk_array_methods(
	'Kharon::Test::TestObj',
	qw/	complicated
		uniq
		encapsulate
		ping_array
		ping_hash
	/);

1;
