#!/usr/bin/env perl 
#-*-perl-*-
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Options;
use PhonyBone::FileUtilities qw(warnf);

use Test::More qw(no_plan);

use FindBin qw($Bin);
use Cwd 'abs_path';
use lib abs_path("$Bin/..");
our $class='QueryGenerator';

BEGIN: {
  Options::use(qw(d q v h fuse=i));
    Options::useDefaults(fuse => -1);
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}

sub main {
    require_ok($class) or BAIL_OUT("$class has compile issues, quitting");
    
    my $qg=$class->new;
    print $qg->prompt, "\n";
    while (my $q=$qg->next) {
	print Dumper($q);
	print $qg->prompt, "\n";
    }
}


main(@ARGV);

