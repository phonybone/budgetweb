#!/usr/bin/env perl 
#-*-perl-*-
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Options;

use Test::More qw(no_plan);

use FindBin qw($Bin);
use Cwd 'abs_path';
use lib abs_path("$Bin/../..");
use Expense qw(remove_quotes_array);

BEGIN: {
  Options::use(qw(d q v h fuse=i));
    Options::useDefaults(fuse => -1);
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}


sub main {
    my $a=[qw('this' 'that' "these" "those")];
    remove_quotes_array($a);
    cmp_ok($a->[0], 'eq', 'this');
    cmp_ok($a->[1], 'eq', 'that');
    cmp_ok($a->[2], 'eq', 'these');
    cmp_ok($a->[3], 'eq', 'those');
}

main(@ARGV);

