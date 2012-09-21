#!/usr/bin/env perl 
#-*-perl-*-
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Options;
use PhonyBone::FileUtilities qw(warnf file_lines);

use Test::More qw(no_plan);

use FindBin qw($Bin);
use Cwd 'abs_path';
use lib abs_path("$Bin/../..");
our $class='ExpenseReader';

BEGIN: {
  Options::use(qw(d q v h fuse=i));
    Options::useDefaults(fuse => -1,
			 test_file => abs_path("$Bin/../test.csv"),
			 quoted_file => abs_path("$Bin/../quoted.csv"),
	);
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}


sub main {
    require_ok($class) or BAIL_OUT("$class has compile issues, quitting");
    test_basic($options{test_file});
    test_basic($options{quoted_file});
}

sub test_basic {
    my ($filename)=@_;
    my $er=new ExpenseReader(file_name=>$filename);
    my $expenses=$er->expenses;
    isa_ok($expenses, 'ARRAY');
    my @lines =file_lines($filename);    
    my $expected=scalar @lines;
    cmp_ok(scalar @$expenses, '==', $expected, "$filename: got $expected expenses");
}

main(@ARGV);

