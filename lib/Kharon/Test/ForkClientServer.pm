package Kharon::Test::ForkClientServer;

use Kharon::Test::TestObj;
use Kharon::Test::TestObjFork;
use Kharon::Test::utils qw/compare compare_array compare_hash/;

use strict;
use warnings;

sub do_both {
	my ($local, $remote, $cmd, @args) = @_;

	print "  Testing $cmd with " . scalar(@args) . " args...";

	my $l = [$local->$cmd(@args)];
	my $r = [$remote->$cmd(@args)];

	compare($l, $r);

	print "\n";
}

sub run_test {

	print "Testing Kharon::Engine using Kharon::Engine::Client::Fork:\n";

	my $local  = Kharon::Test::TestObj->new();
	my $remote = Kharon::Test::TestObjFork->new();

	# Cheesy, reaching past the barrier...  It's okay because it
	# is a test.
	print "  Child is $remote->{kid}\n";

	my %h = ( '!' => '&', ' ' => '=', ',' => ',');

	do_both($local, $remote, 'uniq', "a", "a", "b", (1..255));
	do_both($local, $remote, 'uniq', (1..255), (1..255));
	do_both($local, $remote, 'query');
	do_both($local, $remote, 'inc');
	do_both($local, $remote, 'inc');
	do_both($local, $remote, 'inc');
	do_both($local, $remote, 'inc');
	do_both($local, $remote, 'query');

	for my $i (0..128) {
		do_both($local, $remote, 'inc');
		do_both($local, $remote, 'query');
	}

	do_both($local, $remote, 'complicated');
	do_both($local, $remote, 'encapsulate', (1..255));
	do_both($local, $remote, 'encapsulate', {a=>[(1..255)]});
	do_both($local, $remote, 'encapsulate', {a=>\%h});
	do_both($local, $remote, 'encapsulate', [{a=>\%h}]);
	do_both($local, $remote, 'encapsulate', {a=>[\%h]});
	do_both($local, $remote, 'encapsulate', (1..255), {a=>[(1..255)]});
	do_both($local, $remote, 'encapsulate', [(1..255), {a=>[(1..255)]}]);
	do_both($local, $remote, 'encapsulate', [{a=>[\%h]}]);

	print "\n";
 
	my $kid = $remote->{kid};
	my $default_autoreap = $remote->{pec}->{autoreap};
	my $remote2 = $remote;
 
	print "  Testing that our child dies at the right time...\n";
	die "Kid died early" if ! kill(0, $kid);
	print "    Test before destructor: alive\n";
 
	$remote->{pec}->{autoreap} = 0;
	undef $remote;
	die "Kid got reaped" if ! kill(0, $kid);
	print "    Test after reapless destructor: alive\n";
 
	$remote2->{pec}->{autoreap} = $default_autoreap;
	undef $remote2;
	die "Kid still alive" if kill(0, $kid);
	print "    Test after reapful destructor:  dead\n";
}

1;
