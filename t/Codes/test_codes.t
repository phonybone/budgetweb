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
our $class='Codes';

BEGIN: {
  Options::use(qw(d q v h fuse=i));
    Options::useDefaults(fuse => -1);
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}

sub main {
    require_ok($class) or BAIL_OUT("$class has compile issues, quitting");
    $class->collection_name('codes_test');
    my $code_file=abs_path("$Bin/../../codes.pl");
    $class->initialize(reload=>1, code_file=>$code_file);
    my $codes=$class->instance->load;

    isa_ok($codes, $class);
    isa_ok($codes->mongo, 'MongoDB::Collection');
    cmp_ok($codes->mongo->{name}, 'eq', 'codes_test');

    test_load();
    test_curlies();
    test_next_code();
    test_add();
}

sub test_load {
    my $codes=Codes->instance;
    warn "codes: ",Dumper($codes) if $ENV{DEBUG};
    cmp_ok ($codes->get(5), 'eq', 'Gas', 'Gas');
}

# test literal lookup ("curlies")
sub test_curlies {
    my $codes=Codes->instance;
    cmp_ok ($codes->get(5), 'eq', 'Gas', '{Gas}');
}

sub test_add {
    my $codes=Codes->instance;
    my $new_desc='Bugs Bunny';
    my $new_code=$codes->add($new_desc);
    cmp_ok($new_code, '==', $codes->next_code-1, "new_code: $new_code");
    cmp_ok($codes->get($new_code), 'eq', $new_desc, "new code: $new_code=$new_desc");

    # try adding a dup code:
    my $nc=$codes->next_code;	# next unassigned
    eval {$codes->add($new_desc)};
    like($@, qr/already exists/, "caught add dup code");
    cmp_ok($codes->next_code, '==', $nc, "next_code is still $new_code");

    # and again:
    $nc=$codes->next_code;	# next unassigned
    eval {$codes->add($new_desc)};
    like($@, qr/already exists/, "caught add dup code");
    cmp_ok($codes->next_code, '==', $nc, "next_code is still $new_code");
}

sub test_next_code {
    my $codes=Codes->instance;
    my $nc=$codes->next_code;
    my $cursor=$codes->mongo->find({code=>$nc});
    ok (!$cursor->has_next, "No existing code for next_code=$nc");
    cmp_ok($codes->next_code, '==', $nc, "next_code doesn't inc");
    cmp_ok($codes->next_code, '==', $nc, "next_code doesn't inc");
}

main(@ARGV);

