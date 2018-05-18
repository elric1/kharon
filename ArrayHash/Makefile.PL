use ExtUtils::MakeMaker;

$rel = '0.01';

WriteMakefile(
    'NAME'      => 'Kharon::Protocol::ArrayHash',
    'VERSION'   => $rel,
    'OBJECT'    => "ArrayHash.o arrayhash_perl.o",
);

