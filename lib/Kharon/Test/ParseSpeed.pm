package Kharon::Test::ParseSpeed;

use Time::HiRes qw(gettimeofday tv_interval);

use Kharon::Protocol::ArrayHash;

sub test_it_internal {
	my ($ahp, @strings) = @_;

	$ahp->Reset();
	my $start = [gettimeofday()];

	for my $i (@strings) {
		$ahp->append($i);
	}

	my ($code, @response) = $ahp->Parse();

	return tv_interval($start, [gettimeofday()]). "s";
}

sub test_it {
	my ($ahp, $times) = @_;

	my $str;
	for (my $i=0; $i < $times - 1; $i++) {
		$str .= "250 - host/$i\@EXAMPLE.ORG\r\n";
	}
	$str .= "250 . host/$i\@EXAMPLE.ORG\r\n";

	return test_it_internal($ahp, $str);
}

sub gen_basic {
	my ($end, $var) = @_;

	return "250 $end {a=b,b=c,c=[1,2,3,3,3,3,3,3,3,3,3,3,3,{a=b}],d=$var}".
	    "\r\n";
}

my $hash = "{a={a={a={a={a={a={a={a={a={a={a={a=%s}}}}}}}}}}}}";
my $array = "[[[[[[[[[[[[[[[[[[[[%s]]]]]]]]]]]]]]]]]]]]";
sub gen_complex {
	my ($end, $var) = @_;

	sprintf("250 $end {a=b,b=c,c=[1,2,3,3,3,3,3,3,3,3,3,3,3,{a=b}],d=%s,".
	    "e=$hash,f=$hash,g=$array,h=$array}\r\n", $var, $var, $var, $var,
	    $var);
}

sub test_it_basic {
	my ($ahp, $times) = @_;

	my $str;
	for (my $i=0; $i < $times - 1; $i++) {
		$str .= gen_basic('-', "..$i..");
	}
	$str .= gen_basic('.', "..$i..");

	return test_it_internal($ahp, $str);
}

sub test_it_complex {
	my ($ahp, $times) = @_;

	my $str;
	for (my $i=0; $i < $times - 1; $i++) {
		$str .= gen_complex('-', "..$i..");
	}
	$str .= gen_complex('.', "..$i..");

	return test_it_internal($ahp, $str);
}

sub shorten {
	my ($str) = @_;

	$str =~ s/.*:://;
	return $str;
}

sub produce_table {
	my @protocols = @_;

	my @fields = (map { shorten(ref($_)) } @protocols);

	my $fmt = join(' ', map { '% 15s' } @fields);
	$fmt    = "%- 7s % 10s $fmt\n";

	printf($fmt, 'type', 'iterations', @fields);
	STDOUT->flush();

	for my $i (1,2,4,8,16) {
		printf($fmt, $i==1?'Simple':'', $i."k",
		    map { test_it($_, $i * 1024) } @protocols);
	}

	for my $i (1,2) {
		printf($fmt, $i==1?'Basic':'', $i."k",
		    map { test_it_basic($_, $i * 1024) } @protocols);
	}

	for my $i (1,2) {
		printf($fmt, $i==1?'Complex':'', $i."k",
		    map { test_it_complex($_, $i * 1024) } @protocols);
	}

	print "\n";
}

sub run_test {

	produce_table(Kharon::Protocol::ArrayHash->new());
}

1;
