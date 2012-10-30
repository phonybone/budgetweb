#!/usr/bin/perl
use strict;
use warnings;
use English;
use Carp;
use Data::Dumper;

use lib "$ENV{HOME}/Dropbox/sandbox/perl";
use lib "$ENV{HOME}/Dropbox/sandbox/perl/PhonyBone";
use Options;
use PhonyBone::FileUtilities qw(warnf dief spitString slurpFile);
use PhonyBone::ListUtilities qw(last_n greatest);
use Carp::Assert;

use FindBin qw($Bin);
use Cwd 'abs_path';

use MoneyDB;
use Report;
use Expense;
use Codes;

BEGIN: {
    Options::use(qw(d v no_query append|a keep_transfers 
		    reload_codes clear report_width|rw:i no_report
		  mongo_host:s
		  n_display_cols:i budget_collection:s regex_file:s skip_add));
    Options::useDefaults(
			 mongo_host=>$ENV{EC2_HOST} || 'ec2-50-17-110-122.compute-1.amazonaws.com',
			 keep_transfers=>1,
			 report_width=>6,
			 n_display_cols=>3,
			 budget_collection=>'budget',
			 regex_file=>'regexes',
	);
    Options::required(qw());
    Options::get();

    $ENV{DEBUG}=1 if $options{d};
    $options{verbose}=1 if $options{d};

    $_->host($options{mongo_host}) for qw(Report Expense Codes);
    warn "using mongo host on $options{mongo_host}\n";
}

sub main {
    my @files=@_;
    Codes->initialize(%options);
    my $codes=Codes->instance->load;

    my %moneydb_opts=(codes=>$codes,
		      regex_file=>$options{regex_file},
	);
    MoneyDB->initialize(%moneydb_opts); # initialize is a Singleton method
    my $app=MoneyDB->instance;

    # load new expenses from @files:
    my $expenses=$app->load_file_expenses(@files);
    warnf "%d expenses loaded from %d files\n", scalar @$expenses, scalar @files;

    # insert expenses into db:
    do { $_->save } for @$expenses;
    warnf "%d expenses total\n", Expense->mongo->count();

    # assign codes from regex where possible
    my $n_assigned=$app->regex2code;
    print "$n_assigned expenses assigned by regex\n";

    # Interactive loop to assign codes:
    $app->interactive_add_codes($codes) unless $options{skip_add};

    # Issue report:
    $app->initial_report() unless $options{no_report};

    # fixme: user-generated reports to go here
}

main(@ARGV);

__END__
