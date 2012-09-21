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
our $class='Desc2Code';
use ExpenseReader;

BEGIN: {
  Options::use(qw(d q v h fuse=i));
    Options::useDefaults(fuse => -1,
			 regex_file => abs_path("$Bin/../../regexes"),
			 expense_file => abs_path("$Bin/../test.csv"),
	);
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}


sub main {
    require_ok($class) or BAIL_OUT("$class has compile issues, quitting");
    my $er=new ExpenseReader(file_name=>$options{expense_file});
    my $expenses=$er->expenses;
    my $d2c=$class->new(regex_file=>$options{regex_file});

    my %code_count=();
    foreach my $exp (@$expenses) {
	my $code=$d2c->code_for($exp->bank_desc) || 0;
	$code_count{$code}++ if $code;
    }
    cmp_ok($code_count{1}, '==', 3); # deposits
    cmp_ok($code_count{5}, '==', 2); # gas?
}

main(@ARGV);

