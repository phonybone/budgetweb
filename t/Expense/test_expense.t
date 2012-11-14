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
use Codes;

use PhonyBone::FileUtilities qw(warnf);

BEGIN: {
  Options::use(qw(d q v h fuse=i));
    Options::useDefaults(fuse => -1);
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}


sub main {
    require_ok($class) or BAIL_OUT("$class has compile issues, quitting");
#    $class->collection_name('expense_test');
    warnf "using %s\n", $class->mongo_coords;
    test_constructor();
    test_db_lookup();
    test_regex2code();
}

sub test_constructor {
    my $e=$class->new(['3/4/11', '', 'some bank desc', -34.23]);
    isa_ok($e,$class);
    cmp_ok($e->code, '==', Codes->UNKNOWN);
    cmp_ok($e->month, '==', 3);
    cmp_ok($e->day, '==', 4);
    cmp_ok($e->year, '==', 2011);

    isa_ok($class->new(['3/4/11', '', 'some bank desc', -34.23, 'somecode']), $class);
    isa_ok($class->new(['3/4/11', '', 'some bank desc', -34.23, 5]), $class);

    # withdrawl:
    $e=$class->new('2/11/2012,,POS Withdrawal SAFEWAY 0538 442 W SIMS WAY PORT TOWNSENDWAUS,-28.49,,3');
    isa_ok($e,$class);
    cmp_ok($e->date, 'eq', '2/11/2012', 'date');
    cmp_ok($e->month, '==', 2, 'month');
    cmp_ok($e->day, '==', 11, 'day');
    cmp_ok($e->year, '==', 2012, 'year');
    cmp_ok($e->code, '==', 3, 'code');
    cmp_ok($e->amount, '==', -28.49, 'amount');
    cmp_ok($e->bank_desc, 'eq', 'POS Withdrawal SAFEWAY 0538 442 W SIMS WAY PORT TOWNSENDWAUS', 'desc');
    cmp_ok($e->cheque_no, '==', 0, 'cheque');

    # deposit:
    $e=$class->new('2/9/2012,,External Deposit NUWEST GROUP HOL DINGS LLC 261383035 - QUICKBOOKS,,455.45,1');
    isa_ok($e,$class);
    cmp_ok($e->date, 'eq', '2/9/2012', 'date');
    cmp_ok($e->month, '==', 2, 'month');
    cmp_ok($e->day, '==', 9, 'day');
    cmp_ok($e->year, '==', 2012, 'year');
    cmp_ok($e->code, '==', 1, 'code');
    cmp_ok($e->amount, '==', 455.45, 'amount');
    cmp_ok($e->bank_desc, 'eq', 'External Deposit NUWEST GROUP HOL DINGS LLC 261383035 - QUICKBOOKS', 'desc');
    cmp_ok($e->cheque_no, '==', 0, 'cheque');


    $e=$class->new('"4/30/2012","","External Deposit INSTITUTE FOR SY  - PAYROLL","","2395.07"');
    isa_ok($e,$class);
    cmp_ok($e->date, 'eq', '4/30/2012', 'date');
    cmp_ok($e->cheque_no, '==', 0, 'cheque_no');
    cmp_ok($e->bank_desc, 'eq', "External Deposit INSTITUTE FOR SY  - PAYROLL", 'bank_desc');
    cmp_ok($e->amount, '==', 2395.07, 'amount');
    cmp_ok($e->month, '==', 4, 'month');
    cmp_ok($e->day, '==', 30, 'day');
    cmp_ok($e->year, '==', 2012, 'year');
}

sub test_db_lookup {
    my $exp1=$class->find({},{limit=>1})->[0];
    isa_ok($exp1, $class);
    my $id=$exp1->_id->value;

    my $exp2=$class->new($id);
    isa_ok($exp2, $class);

    # is_deeply was choking on an overloaded string operator, so:
    foreach my $field (qw(date bank_desc amount code month day year ts)) {
	cmp_ok($exp1->$field, 'eq', $exp2->$field, $field);
    }
}


sub test_regex2code {
  SKIP: {
      skip "skipping regex2code tests, NYI", 0 if 1;
      die "NYI";
    }
}

main(@ARGV);

