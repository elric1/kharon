use strict;
use warnings;
use ExtUtils::MakeMaker;

#
# We allow a number of env vars to control the behaviour of Makefile.PL:
#
#	KHARON_ENABLE_DEVELOPER		Turns on compiler warnings.  This may
#					break on many arches because warnings
#					vary depending on the version of the
#					compiler.
#	KHARON_KNCPATH			Path to knc (defaults to /usr/bin/knc).
#					(May not contain commas.)

our @warnings = qw/	-Werror -Wall
			-Wstrict-prototypes -Wmissing-prototypes
			-Wpointer-arith -Wno-sign-compare
			-Wno-traditional -Wreturn-type -Wswitch
			-Wno-shadow -Wcast-qual -Wwrite-strings -Wextra
			-Wno-unused-parameter -Wsign-compare/;

if (!defined($ENV{KHARON_ENABLE_DEVELOPER}) || !$ENV{KHARON_ENABLE_DEVELOPER}) {
	@warnings = ();
}

my %args = (
	NAME		=> 'Kharon',
	AUTHOR		=> q{Roland C. Dowdeswell <elric@imrryr.org>},
	VERSION_FROM	=> 'lib/Kharon.pm',
	ABSTRACT_FROM	=> 'lib/Kharon.pm',
	LICENSE		=> 'MIT',
	PL_FILES	=> {},
	DIR		=> ['ArrayHash'],
	OPTIMIZE	=> '-O2 -g ' . join(' ', @warnings),
	dist		=> { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
	clean		=> { FILES => 'Kharon-*' },
);

if (defined($ENV{KHARON_KNCPATH})) {
	$args{PM_FILTER} = qq{sed -e 's,/usr/bin/knc,$ENV{KHARON_KNCPATH},g'};
}

WriteMakefile(%args);
