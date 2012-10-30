package TestExpenseREST;
use Catalyst::Test 'budgetweb';
use namespace::autoclean;

use Moose;
extends 'PhonyBone::TestCase';
use parent qw(PhonyBone::TestCase); # for method attrs, sigh...
use Test::More;
use Expense;
use Report;
use Codes;

before qr/^test_/ => sub { shift->setup };

sub _init {
    $_->host('localhost') for qw(Report Expense Codes);
}

sub test_expense_GET : Testcase {
    my ($self, $oid)=@_;

    my $expense=new Expense($oid);
    isa_ok($expense, 'Expense');

    my $res=request('/expense/$oid');
    ok ($res->is_success, '/expense/$oid' );
    my $content=$res->content;
    my $exp_data=from_json($content);
    my $expense2=new Expense(%$exp_data);
    is_deeply($expense, $expense2);
}

__PACKAGE__->_init;
__PACKAGE__->meta->make_immutable;

1;
