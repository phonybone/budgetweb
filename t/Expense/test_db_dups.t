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
use lib abs_path("$Bin/../..");
our $class='Expense';

use ExpenseReader;
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
    test_one($tester);
    test_many($tester);
}


# tests Expense::has_dup_in_db
sub test_one {
    my ($tester)=@_;
    $tester->setup();
    my $record=$class->mongo->find({}, {limit=>1})->next;
    my $e1=$class->new(%$record);
    $e1->code(Codes->UNKNOWN);

    my $dup_record=$e1->has_dup_in_db();
    cmp_ok(ref $dup_record, 'eq', 'HASH');
    my $dup=$class->new(%$dup_record);
    foreach my $f (@{$class->field_order}) {
	unless ($f eq 'code' || $f eq 'ts') {
	    cmp_ok($e1->$f, 'eq', $dup->$f, $f);
	}
    }
}

# tests Expense::remove_existing
sub test_many {
    my ($tester)=@_;
    my $expenses=$tester->setup();
    my $null_list=$class->remove_existing($expenses); # should remove all
    is_deeply($null_list, [], 'got null list');

    
}

main(@ARGV);

