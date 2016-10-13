
use Test::More tests=>1;

use Kharon::Test::CLI;
use Kharon::Test::TestObjFork;

my $obj = Kharon::Test::TestObjFork->new();
my $cli = Kharon::Test::CLI->new(appname => 'test', json => 1);

$cli->set_obj($obj);

ok(1);

done_testing();
