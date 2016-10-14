#
#

use Test::More;

use Kharon::Entitlement::ACLFile;
use Kharon::Entitlement::Dispatch;
use Kharon::Entitlement::Equals;

use strict;
use warnings;

sub run_test {
	my $icreds1 = ['elric@IMRRYR.ORG'];
	my $mcreds1 = ['elric@NETBSD.ORG'];
	my $icreds2 = ['someguy@EXAMPLE.COM'];

	my $krb  = Kharon::Entitlement::Equals->new();
	check_must($krb,  1, $icreds1, 'elric@IMRRYR.ORG');
	check_must($krb,  0, $mcreds1, 'elric@IMRRYR.ORG');

	my $disp = Kharon::Entitlement::Dispatch->new();
	$disp->register_handler("krb",   $krb);

	check_must($disp, 1, $icreds1, 'krb://elric@IMRRYR.ORG');
	check_must($disp, 0, $mcreds1, 'krb://elric@IMRRYR.ORG');
}

sub check_must {
	my ($class, $result, $creds, @ents) = @_;
	my $obj;

	if (ref($class) eq '') {
		$obj = $class->new(credlist => $creds);
	} else {
		$obj = $class;
		$obj->set_creds(@$creds);
	}
	$class = ref($obj);

	ok($obj->check(@ents) == $result,
	    "Failed.  $creds should return $result");
}

run_test();
done_testing();
