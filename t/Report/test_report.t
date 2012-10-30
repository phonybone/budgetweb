#!/usr/bin/env perl 
#-*-perl-*-
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Options;
use PhonyBone::FileUtilities qw(warnf);
use PhonyBone::StringUtilities qw(trim);

use Test::More qw(no_plan);

use FindBin qw($Bin);
use Cwd 'abs_path';
use lib abs_path("$Bin/../..");
our $class='Report';
use Codes;
use QueryGenerator;
use Mongoid;

BEGIN: {
  Options::use(qw(d q v h fuse=i query_file=s));
    Options::useDefaults(fuse => -1, query_file=>"$Bin/queries.txt");
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}

sub main {
    require_ok($class);
    my $codes=Codes->instance->load;
    isa_ok($codes, 'Codes') or BAIL_OUT("Codes is broken");
    test_table_report();
    test_EOT() or BAIL_OUT("EOT failed");
    test_mongo() or BAIL_OUT("mongo failed");
    test_query_db() or BAIL_OUT("query_db failed");
    test_stringify() or BAIL_OUT("stringify failed");
    test_bounds() or BAIL_OUT("bounds failed");
    test_monthly_totals_line() or BAIL_OUT("monthly_totals_line failed");

    exit;

    test_queries() or BAIL_OUT("queries failed");
}

sub test_EOT {
    my $report=Report->new;
    cmp_ok ($report->start_ts, 'eq', 0, 'start_ts default');
    cmp_ok ($report->stop_ts, 'eq', 3_355_184_000, 'stop_ts default'); # fixme! should really figure out how to import that constant
}


sub test_mongo {
    my $report=Report->new(start=>'9/11/2011', stop=>'12/11/2011', code=>5);
    my $mongo=$report->mongo;
    isa_ok ($mongo, 'MongoDB::Collection', 'got MongoDB::Collection');
    cmp_ok ($mongo->full_name, 'eq', join('.', $report->db_name, $report->collection_name), (sprintf "got %s", $mongo->full_name));
}

# partial test to query db with hash-literal query
sub test_query_db {
    my $report=Report->new(start=>'9/11/2011', stop=>'12/11/2011', code=>5);
    cmp_ok ($report->count, 'gt', 0, sprintf("got %d expenses", $report->count));

    my $cursor=$report->cursor;
    while ($cursor->has_next) {
	my $expense=$cursor->next;
	cmp_ok($expense->{code}, 'eq', $report->code);
    }
    1;
}

# set up a report using a short script and QueryGenerator, then display all lines:
sub test_queries {
    my $qg=QueryGenerator->new(read=>$options{query_file});
    while (my $query=$qg->next) {
	my $report=Report->new(%$query);
	my $cursor=$report->cursor;
	while ($cursor->has_next) {
	    my $expense=Expense->new(%{$cursor->next});
#	    warn "$expense\n";
	}
    }
    1;
}


# produce a table report, go through it line by line
sub test_table_report {
    my $report=Report->new(start=>'9/11');
    my $output=$report->table_report;
    my @lines=split("\n", $output);

    # header line
    my $month_line=trim(shift @lines);
    like($month_line, qr'(\d+/\d+)+', "got '3/12' type headings");

    # Item lines
    my $re=qr/^(-?[\d.]+|--)$/;
    my $monthly_line;
    foreach my $line (@lines) {
	if ($line =~ /Monthly totals/) {
	    $monthly_line=$line;
	    last;
	}
	my @fields=split(/\s+/, trim($line));
	shift @fields;
	shift @fields;
	shift @fields;
	shift @fields;
	foreach my $field (@fields) {
	    like($field, $re);
	}
    }

    # Monthly total line
    my @fields=split(/\s+/, trim($monthly_line));
    cmp_ok(shift @fields, 'eq', 'Monthly');
    cmp_ok(shift @fields, 'eq', 'totals:');
    foreach my $field (@fields) {
	like($field, qr/^-?\d[\d.]+$/);
    }
}

# test Report::as_string, which produces a line-item report
# across the date range and code
sub test_stringify {
    my $report=Report->new(start=>'9/11/2011', stop=>'12/11/2011', code=>5);
    isa_ok($report, 'Report', 'got a Report object');
    my $r="$report";		# calls Report::as_string

    foreach my $line (split("\n", $r)) {
	my ($date, $bdesc, $amount, $cdesc)=split(/\s+\|\s+/, $line);
	ok ($date=~m|^\s*\d\d?/\d\d?/\d\d\d\d$|, "'$date'");
	ok ($amount=~/^\s*[-\d.]+$/, "'$amount'");
    }

    1;
}

sub test_no_start {
    my $code=shift;
    my %args=(stop=>'12/11/2011');
    $args{code}=$code if $code;
    my $report=Report->new(%args);

    isa_ok($report, 'Report', 'got a Report object');
    cmp_ok($report->count, '>', 0, sprintf("got %d items up to  %s", $report->count, $args{stop}))
	or return 0;
    $report->count;
}


sub test_no_stop {
    my $code=shift;
    my %args=(start=>'12/12/2011');
    $args{code}=$code if $code;
    my $report=Report->new(%args);

    isa_ok($report, 'Report', 'got a Report object');
    cmp_ok($report->count, '>', 0, sprintf("got %d items starting from  %s", $report->count, $args{start}))
	or return 0;
    $report->count;
}

sub test_bounds {
    my $n_no_start=test_no_start() or return 0;
    my $n_no_stop=test_no_stop() or return 0;
    
    my $report=Report->new;
    cmp_ok($report->count, '==', $n_no_start+$n_no_stop, sprintf("got %d total", $report->count));

    my $random_code=16;
    $n_no_start=test_no_start($random_code) or return 0; # $random_code is some random code
    $n_no_stop=test_no_stop($random_code) or return 0;

    $report=Report->new(code=>$random_code);
    cmp_ok($report->count, '==', $n_no_start+$n_no_stop, sprintf("got %d total (code=$random_code)", $report->count));
}

sub test_monthly_totals_line {
    my $report=Report->new(start=>'3/11', stop=>'4/12');
    isa_ok($report, 'Report', 'got a Report object');
    $report->table_report;	# ignore return value for now
    my $mks=$report->mks;
    my $mtl=$report->monthly_totals_line;
    my @parts=split(/\s+/, trim($mtl));
    like(shift @parts, qr/Monthly/) or return 0;
    like(shift @parts, qr/totals/) or return 0;
    do { like ($_, qr/^-?\d+\.\d+$/) or return 0 } for @parts;
    1;
}

main(@ARGV);



