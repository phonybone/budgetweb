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
    isa_ok($codes->collection, 'MongoDB::Collection');
    cmp_ok($codes->collection->{name}, 'eq', 'codes_test');

    test_load();
    test_curlies();
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
    my $new_desc='bugs bunny';
    my $new_code=$codes->add($new_desc);
    cmp_ok($new_code, '==', $codes->next_code-1, "new_code: $new_code");
    cmp_ok($codes->get($new_code), 'eq', $new_desc, "new code: $new_code=$new_desc");

    # try adding a dup code:
    eval {my $new_code2=$codes->add($new_desc)};
    like($@, qr/already exists/, "caught add dup code");
    
}

main(@ARGV);

