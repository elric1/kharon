#
#

use Data::Dumper;
use Test::More;

use Kharon::Protocol::ArrayHash;
use Kharon::Protocol::ArrayHashPerl;

use strict;
use warnings;

sub encode_parse {
	my ($proto, @vars) = @_;
	my ($p1, $p2) = @$proto;

	$p1->Reset();
	my @response = $p1->Encode(250, @vars);

	$p2->Reset();
	# XXXrcd: not right!
	for my $i (@response) {
		$p2->append($i);
	}

	my ($code, @result);
	eval {
		($code, @result) = $p2->Parse();
	};

	ok(!$@, "encode_parse: $@");

	is_deeply([$code, @result], [250, \@vars]);
}

sub marshalling {
	my ($proto, @vars) = @_;
	my ($p1, $p2) = @$proto;

	my $str = $p1->Marshall(\@vars);
	my @args = $p2->Unmarshall($str);


#	compare(\@vars, \@args);
# the above line is correct: XXXrcd
	is_deeply(\@vars, @args);
}

sub test_protocol {
	my ($class1, $class2) = @_;

	my $p1 = $class1->new();
	my $p2 = $class2->new();
	my $proto = [$p1, $p2];

	# First we prepare a simple array and a hash that will be used below.
	# we perform very simple tests during the preparation.

	my @a;
	my %h;
	for my $i (map {chr($_)} (0..255)) {
		push(@a, $i);
		$h{$i} = $i . "---------,.,.,.,';:';:'-_==+++" . $i;
		for my $j (' ', ',', qw|! = + & [ ] { } ( )|) {
			push(@a, "$i:$j");
			$h{"$i:$j"} = $j;
		}
	}

	encode_parse($proto);
	encode_parse($proto, undef);
	encode_parse($proto, '');
	encode_parse($proto, '', '', 'a');
	encode_parse($proto, '!');
	encode_parse($proto, join('', map { chr($_) } (0..255)));
	encode_parse($proto, map { chr($_) } (0..255));

	# XXXrcd: Perl parser can't deal with these:
	if ("$class1 $class2" !~ /Perl/) {
		encode_parse($proto, []);
		encode_parse($proto, ['']);
	}
	encode_parse($proto, [undef]);
	encode_parse($proto, ['!']);
	encode_parse($proto, [map { chr($_) } (0..255)]);

	encode_parse($proto, ["foo", "bar"]);
	encode_parse($proto, @a);
	encode_parse($proto, \@a);
	encode_parse($proto, ["foo", "bar"], \@a);
	encode_parse($proto, [(0..32)], \@a);

	# XXXrcd: Perl parser can't deal with this:
	if ("$class1 $class2" !~ /Perl/) {
		encode_parse($proto, {});
	}
	encode_parse($proto, {1=>undef});
	encode_parse($proto, {1=>''});
	encode_parse($proto, {1=>'!'});
	encode_parse($proto, {a=>'b', c=>'d', e=>'f'}, {t=>'v'});
	encode_parse($proto, {a=>'b', c=>'d', e=>'f'}, {9=>'1'});
	encode_parse($proto, {map { $_ => $_ } (0..255)});

	for my $key (keys %h) {
		encode_parse($proto, {$key => $h{$key}});
	}

	encode_parse($proto, "foo");
	encode_parse($proto, "bar", "foo");
	encode_parse($proto, {a=>[(0..32)], b=>{c=>'d', e=>'=foo!'}});
	encode_parse($proto, [1,2,3,4,5,{a=>'b'}], "!");

	encode_parse($proto, \%h);
	encode_parse($proto, [\%h]);
	encode_parse($proto, ["foo", @a]);
	encode_parse($proto, ["foo", \@a]);
	encode_parse($proto, ["foo", \%h]);
	encode_parse($proto, [(0..32), @a]);
	encode_parse($proto, [(0..32), \@a]);
	encode_parse($proto, [(0..32), \%h]);
	encode_parse($proto, [[{a=>{b=>{c=>{d=>{e=>{f=>[\%h, \@a]}}}}}}]], "1");
	encode_parse($proto, [(0..32), \%h, [1, [[[[[[[[[[\%h]]]]]]]]]]]]);
	encode_parse($proto, {aa=>[(0..32)], '!' => \%h});
	encode_parse($proto, {bb=>[(0..32)], '=' => \@a});
	encode_parse($proto, {cc=>[(0..32)], ',' => ["!", [[[(0..32)]]], \%h]});
	encode_parse($proto, {dd=>[(0..32)], ' ' => ["=", [[[(0..32)]]], \%h]});
	encode_parse($proto, {ee=>[(0..32)], '^' => ["&", [[[(0..32)]]], \%h]});
	encode_parse($proto, {ff=>[(0..32)], '&' => [",", [[[(0..32)]]], \%h]});

	marshalling($proto, 'a', 'b! !c');

	for my $i (map { chr($_) . "+" } (32..127)) {
		marshalling($proto, "$i");
	}

	marshalling($proto, 'a', join(' ', map { chr($_) . "+" } (32..127)));
	marshalling($proto, 'a', join(' ', map { chr($_) . "fsadf" } (0..255)));

	#
	# First we make @a and %h more ``interesting'':

	unshift(@a, '');
	$h{asdcasdc} = '';
	$h{foobarzz} = \@a;

	marshalling($proto, 'cmd', @a);
	marshalling($proto, 'cmd', \@a);
	marshalling($proto, 'cmd', \%h);
	marshalling($proto, 'cmd', [[[[[\@a]]]]]);
	marshalling($proto, 'cmd', [1,[2,[[[\@a]]]]]);
	marshalling($proto, 'cmd', [[[[[\%h]]]]]);
	marshalling($proto, 'cmd', [[1,[[2,[\%h]]]]]);
}

my @protos = qw/Kharon::Protocol::ArrayHash
		Kharon::Protocol::ArrayHashPerl/;

for my $p1 (@protos) {
	for my $p2 (@protos) {
		test_protocol($p1, $p2);
	}
}

done_testing();
