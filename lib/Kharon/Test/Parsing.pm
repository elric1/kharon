package Kharon::Test::Parsing;

use Kharon::utils qw{encode_var get_next_var tokenise};

use strict;
use warnings;

sub test_string {
	my ($in) = @_;

#	my ($tmp, $rest) = get_next_var([$in]);
#	my $out = encode_var($tmp, '[ ]');
	my @tmp = tokenise(["$in\r\n"]);
	my $out = encode_var($tmp[0], '[ ]');
	$out;
}

sub test_var {
	my ($test) = @_;
	my $in;
	my $out;

	eval {
		$in  = encode_var($test, '[ ]');
		$out = test_string($in);
	};

	print STDERR $@ if $@;

	if ($@ || $in ne $out) {
		print STDERR "Test failed: $test\n";
		print STDERR "IN:  $in.\n";
		print STDERR "OUT: $out.\n";
		die "FAILED!\n";
	}
}

sub test_var_all_contexts {
	my ($var) = @_;

	test_var($var);
	test_var([$var]);
	test_var({a => $var});
}

sub test_scalar_all_contexts {
	my ($var) = @_;

	test_var_all_contexts($var);
	test_var({$var => 'a'});
}

sub expect_parse_error {
	my ($test) = @_;

	eval {
		test_string($test);
	};
	if (!$@) {
		die "FAILED: expected error but didn't get one in \"$test\".\n";
	}
}

sub run_test {

	print "Running parsing tests... ";

	#
	# Let's do a few simple cases first:

	my @ret;
	@ret = tokenise(['']);
	die "did not get () from ''" if scalar(@ret);

	@ret = tokenise(['!']);
	die "did not get (undef) from '!'"
	    if scalar(@ret) != 1 || defined($ret[0]);

	#
	# We test a few random ideas that popped into Mine Head at the
	# time that I was writing the code.  Some of these happen to catch
	# regressions of behaviours that I found while testing...  And some
	# are units that I decided to write while testing.  I'm not going to
	# tell you which is which, though.  That's for you to guess...

	test_var(undef);
	test_var(' {a=b}');
	test_var('{a=b}');
	test_var('a{a=b}');
	test_var('a/b.ms.com@EXAMPLE.ORG');
	test_var('a b');
	test_var({version=>'2.0'});
	test_var(['a','b']);
	test_var({a=>'b', c=>'d'});
	test_var(['a','b',{foo=>'bar', baz => 'boodle'}, 5]);
	test_var({a=>{foo=>'bar'}});
	test_var(['a','b',{foo=>[1,2], baz => {a=>'b',c=>'d'}}, [1,2]]);
	test_var(['a',[1]]);
	test_var({'a b' => 'c d'});
	test_var({'a=b' => 'c=d'});
	test_var({'a,b' => 'c,d'});
	test_var({'a}b' => 'c}d'});
	test_var({'a}b' => ' c}d'});
	test_var({' a}b' => ' c}d'});
	test_var({a=>undef});

	#
	# We test to ensure that we get errors on a few things that
	# should return errors:

	expect_parse_error('{a=b,c');
	expect_parse_error('[1,2,3,4,5');
	expect_parse_error('{a=b,c=[1,2,3]');
	expect_parse_error("abcd\\");

	#
	# And now, let's make sure that all of our escaping is working by
	# building a variable which contains every character and putting it
	# in all of the places where it might occur:

	test_scalar_all_contexts(join('', map {chr($_)} (0..255)));

	#
	# And another one.  Let's try all possible characters to start and end
	# a variable or single vars of any char...:

	for my $i (0..255) {
		test_scalar_all_contexts(chr($i)                     );
		test_scalar_all_contexts(chr($i) . "foodle"          );
		test_scalar_all_contexts(chr($i) . "foodle" . chr($i));
		test_scalar_all_contexts(          "foodle" . chr($i));
	}

	print "SUCCESS\n\n";
}

1;
