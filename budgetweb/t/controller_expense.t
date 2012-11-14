#!/usr/bin/env perl 
#-*-perl-*-
use strict;
use warnings;
use Carp;
use Data::Dumper;
use PhonyBone::FileUtilities qw(warnf);

use Test::More qw(no_plan);

use FindBin qw($Bin);
use Cwd 'abs_path';
use lib abs_path("$Bin/../lib");
use lib abs_path("$Bin/../..");	# for Expense.pm, Codes.pm, etc
use lib "$Bin";

use Options;			
use TestExpenseREST;		# derived from PhonyBone::TestCase

our $class='budgetweb::Controller::expense';


BEGIN: {
  Options::use(qw(d q v h fuse=i));
    Options::useDefaults(fuse => -1);
    Options::get();
    die Options::usage() if $options{h};
    $ENV{DEBUG} = 1 if $options{d};
}


sub main {
    my $tc=new TestExpenseREST(class=>$class);
    warnf "using %s\n", Expense->mongo_coords;
    $tc->test_compiles();
    $tc->test_expense_GET('4fc50296256d55d9660003b2');
    $tc->test_find_next('4fc50296256d55d9660003b2');
    $tc->test_unknown;
    $tc->test_get_codes;
    $tc->test_expense_POST('4fc50296256d55d9660003b2');
}

main(@ARGV);




__END__


use strict;
use warnings;
use Test::More;
use TestExpenseREST;



ok( request('/expense')->is_success, 'Request should succeed' );
done_testing();
