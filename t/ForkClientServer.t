#
#

use Test::More;

use Kharon::Test::TestObj;
use Kharon::Test::TestObjFork;

use strict;
use warnings;

sub do_both {
	my ($local, $remote, $cmd, @args) = @_;

	my $l = [$local->$cmd(@args)];
	my $r = [$remote->$cmd(@args)];

	is_deeply($l, $r);
}

my $local  = Kharon::Test::TestObj->new();
my $remote = Kharon::Test::TestObjFork->new();

# Cheesy, reaching past the barrier...  It's okay because it
# is a test.

my $ret = $remote->retnothing();
if (defined($ret)) {
	die "method retnothing evaluated in a scalar context should " .
	    "be undef";
}

my @ret = $remote->retnothing();
if (@ret > 0) {
	die "method retnothing evaluated in a array context should " .
	    "have zero length";
}

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

#
# Test the input validation:

my $hr = {1=>2,3=>4};

my $res = $remote->takes_one_hashref($hr);
is_deeply($hr, $res);

# These should fail:

eval { $remote->takes_one_hashref() };
die "IV#1 failed"	if (!$@ || $@ ne "Too few args\n");
eval { $remote->takes_one_hashref(1) };
die "IV#2 failed"	if (!$@ || $@ ne "Not a hashref\n");
eval { $remote->takes_one_hashref("foo") };
die "IV#3 failed"	if (!$@ || $@ ne "Not a hashref\n");
eval { $remote->takes_one_hashref($hr, $hr) };
die "IV#4 failed"	if (!$@ || $@ ne "Too many args\n");

#
# Reaping and so on:

my $kid = $remote->{kid};
my $default_autoreap = $remote->{pec}->{autoreap};
my $remote2 = $remote;

die "Kid died early" if ! kill(0, $kid);

$remote->{pec}->{autoreap} = 0;
undef $remote;
die "Kid got reaped" if ! kill(0, $kid);

$remote2->{pec}->{autoreap} = $default_autoreap;
undef $remote2;
die "Kid still alive" if kill(0, $kid);

done_testing();
