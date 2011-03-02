package Kharon::Protocol::ArrayHash;

# use 5.012002;
use strict;
use warnings;
use Carp;

require Exporter;
require DynaLoader;
use AutoLoader; #  'AUTOLOAD';

our @ISA = qw(Exporter DynaLoader Kharon::Protocol::Base);

our $VERSION = '0.01';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&PKG::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
        no strict 'refs';
            *$AUTOLOAD = sub { $val };
    }
    goto &$AUTOLOAD;
}

bootstrap Kharon::Protocol::ArrayHash;

1;
__END__
