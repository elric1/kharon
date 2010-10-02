use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Kharon',
    AUTHOR              => q{Roland C. Dowdeswell <elric@imrryr.org>},
    VERSION_FROM        => 'lib/Kharon.pm',
    ABSTRACT_FROM       => 'lib/Kharon.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
#    PREREQ_PM => {
#        'Test::More' => 0,
#    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Kharon-*' },
);
