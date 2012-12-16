#!/usr/bin/env perl 
use strict;
use warnings;
use Carp;
use Data::Dumper;
 
use Options;			# PhonyBone::Options, sorta

use FindBin qw($Bin);
use Cwd qw(abs_path);
use lib "$Bin";
use lib abs_path("$Bin/../lib");

use Expense;
use FixCodes;


BEGIN: {
  Options::use(qw(d q v h fuse=i dryrun start_ts=i stop_ts=i));
    Options::useDefaults(fuse => -1);
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}


sub main {
    my @args=@_;
    my $op=shift @args or die usage(qw(op));
    my $fc=FixCodes->new;
    if (! $fc->can($op)) {
	die "unknown op '$op'\n";
    }
    my $stats=$fc->$op(\%options);
    warn Dumper($stats);
    warn Dumper(\%options);
}



main(@ARGV);

