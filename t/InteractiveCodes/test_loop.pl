#!/usr/bin/env perl 
#-*-perl-*-
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Options;
use Codes;
use Expense;
use ExpenseReader;
use PhonyBone::FileUtilities qw(warnf);

use Test::More qw(no_plan);

use FindBin qw($Bin);
use Cwd 'abs_path';
use lib abs_path("$Bin/../..");
our $class='InteractiveCodes';

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

    # must be a better way to do this, to insure that no classes get left out...
    Expense->db_name('test_money');
    Codes->db_name('test_money');
    Report->db_name('test_money');

    my $ic=$class->new;
    Codes->initialize(code_file=>abs_path("$Bin/../../codes.pl"), reload=>1);
    my $codes=instance Codes;
    $codes->load;

    Expense->delete_all;
    my $test_file = shift || $options{test_file};
    my $er=new ExpenseReader(file_name=>$test_file);
    my $expenses=$er->expenses;
    warnf "$0: got %d expenses\n", scalar @$expenses;

    # force all expense codes to be UNKNOWN
    $_->code(Codes->UNKNOWN) for @$expenses;
    $_->save({safe=>1}) for @$expenses;

    $ENV{DEBUG}=1;
    $ic->loop($expenses, $codes);

    my %histo;
    $histo{$_->code}++ for @$expenses;
#    warnf "histo: %s", Dumper(\%histo);

    # show a report:
    my $r=Report->new;
    print $r->table_report, "\n";

}

main(@ARGV);

