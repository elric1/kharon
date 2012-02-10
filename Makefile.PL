use strict;
use warnings;
use ExtUtils::MakeMaker;

our @warnings = qw/	-Wall
			-Wstrict-prototypes -Wmissing-prototypes
			-Wpointer-arith -Wno-sign-compare
			-Wno-traditional -Wreturn-type -Wswitch
			-Wno-shadow -Wcast-qual -Wwrite-strings -Wextra
			-Wno-unused-parameter -Wsign-compare/;
# @warnings = ();

WriteMakefile(
    NAME                => 'Kharon',
    AUTHOR              => q{Roland C. Dowdeswell <elric@imrryr.org>},
    VERSION_FROM        => 'lib/Kharon.pm',
    ABSTRACT_FROM       => 'lib/Kharon.pm',
    LICENSE		=> 'MIT',
    PL_FILES            => {},
    DIR			=> ['ArrayHash'],
    OPTIMIZE		=> '-O2 -g ' . join(' ', @warnings),
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Kharon-*' },
);
