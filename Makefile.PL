use ExtUtils::MakeMaker;

WriteMakefile(
  'AUTHOR'		=> 'Dan Brumleve <dan_brumleve@yahoo.com>',
  'NAME'		=> 'wildproto',
  'VERSION_FROM'	=> 'wildproto.pm',
  clean			=> {FILES => '*.so'},
);
