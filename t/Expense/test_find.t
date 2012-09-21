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
our $class='Expense';

use t::Expense::TestExpense;

BEGIN: {
  Options::use(qw(d q v h fuse=i));
    Options::useDefaults(fuse => -1,
			 test_file => abs_path("$Bin/../test.csv"),
	);
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}


sub main {
    require_ok($class) or BAIL_OUT("$class has compile issues, quitting");
    t::Expense::TestExpense->initialize(test_file=>$options{test_file});
    my $tester=t::Expense::TestExpense->instance;

    test_find_all($tester) or BAIL_OUT("find_all() failed");
    test_find_eqs($tester) or BAIL_OUT("find_eqs() failed");
    test_find_regex($tester) or BAIL_OUT("find_regex() failed");
}

sub test_find_all {
    my ($tester)=@_;
    $tester->setup();
    my $expenses=Expense->find(); # gets all of them
    isa_ok($expenses, 'ARRAY') or return 0;
    cmp_ok(scalar @$expenses, '==', 26, 'got 26 expenses') or return 0;
    1;
}

sub test_find_eqs {
    my ($tester)=@_;
    $tester->setup();
    my $expenses=Expense->find({date=>'2/11/2012'});
    isa_ok($expenses, 'ARRAY') or return 0;
    cmp_ok(scalar @$expenses, '==', 5, 'got 5 expenses') or return 0;
    1;
}

sub test_find_regex {
    my ($tester)=@_;
    $tester->setup();
    my $expenses=Expense->find({bank_desc=>qr/POS Withdrawal/});
    isa_ok($expenses, 'ARRAY') or return 0;
    cmp_ok(scalar @$expenses, '==', 18, 'got 18 expenses') or return 0;
    1;
}

main(@ARGV);

