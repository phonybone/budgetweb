#!/usr/bin/env perl 
#-*-perl-*-
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Options;
use Codes;
use Expense;

use Test::More qw(no_plan);

use FindBin qw($Bin);
use Cwd 'abs_path';
use lib abs_path("$Bin/../..");
our $class='InteractiveCodes';

BEGIN: {
  Options::use(qw(d q v h fuse=i));
    Options::useDefaults(fuse => -1);
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}


sub main {
    require_ok($class) or BAIL_OUT("$class has compile issues, quitting");
    my $ic=$class->new;
    Codes->db_name('test_money');
    Codes->initialize(code_file=>abs_path("$Bin/../../codes.pl"), reload=>1);
    my $codes=instance Codes;


    my $exp=new Expense(date=>'3/7/12', 
			bank_desc=>'whatevs',
			amount=>10,
			code=>Codes->UNKNOWN,
			month=>3,
			day=>7,
			year=>2012,
	);
    $ENV{DEBUG}=1;
    my $code=$ic->loop1($exp, $codes);
    my $desc=$codes->{$code};
    warn "code is $code ($desc)\n";
}

main(@ARGV);

