package TestExpenseREST;
use Catalyst::Test 'budgetweb';
use namespace::autoclean;
use PhonyBone::FileUtilities qw(warnf);
use HTTP::Request::Common;
use Data::Dumper;
use JSON;
use Data::Structure::Util qw(unbless);

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
    warn "oid is $oid";
    my $expense=new Expense($oid);
    isa_ok($expense, 'Expense') or do {
	warnf "$oid: no expense found\n";
	return;
    };

    my $req=GET "/expense/$oid", 'Content-type' => 'application/json';
    my $res=request $req;
    ok ($res->is_success, "/expense/$oid" ) or do {
	warn "error: ", $res->status_line;
	return;
    };
    my $content=$res->content;
    my $exp_data=from_json($content);
    $exp_data->{_id}=MongoDB::OID->new(value=>$exp_data->{_id}->{value}); # hack
    my $expense2=new Expense(%$exp_data);
    is_deeply($expense, $expense2);
}

sub test_find_next {
    my ($self, $oid)=@_;
    my $uri="/expense/$oid/edit_next";
    my $res=request($uri);
    warn "res is $res";
}

sub test_unknown {
    my ($self)=@_;
    my $uri="/expense/unknown";
    my $req=GET $uri, 'Content-type' => 'application/json';

    my $res=request($req);
    ok ($res->is_success, "$uri succeeded") or return;
    my $data=eval {from_json($res->content)};
    cmp_ok($@, 'eq', '', 'data converted from json') or return;
    cmp_ok($data->{count}, '>=', 0, sprintf "got %d expenses", $data->{count});
    my $expenses=$data->{expenses};
    isa_ok($expenses, 'ARRAY', $expenses) or return;
    cmp_ok(scalar @$expenses, '==', $data->{count}, 'list length ok');
    my $record=$expenses->[0];
    my $oid=MongoDB::OID->new(value=>$record->{_id}->{'$oid'});
    isa_ok($oid, 'MongoDB::OID') or return;
    $record->{_id}=$oid;
    $record->{cheque_no}=0 if ($record->{cheque_no} eq 'xxx');
    my $exp=eval {Expense->new(%{$record})};
    cmp_ok($@, 'eq', '', 'made an Expense from first record') or return;
    isa_ok($exp, 'Expense');
    cmp_ok($exp->code, '==', Codes->UNKNOWN);

    my $n_unknown=grep {$_->{code} == Codes->UNKNOWN} @{$expenses};
    cmp_ok($n_unknown, '==', scalar @{$expenses});
}

sub test_get_codes : Testcase {
    my ($self)=@_;
    my $url='/expense/codes';
    my $req=GET $url, 'Content-type' => 'application/json';
    my $res=request($req);
    ok ($res->is_success, "$url succeeded") or return;
    my $codes=from_json($res->content);
    isa_ok($codes, 'HASH', "codes are a HASH");
    foreach my $pair (([-2, 'Unknown'],
		       [1, 'Deposit'],
		       [5, 'Gas'],
		       [16, 'Mortgage'],
		       [40, 'Paris'])) {
	my ($code, $desc)=@$pair;
	cmp_ok($codes->{$code}, 'eq', $desc, sprintf "%d -> %s", $code, $desc);
    }
}

sub test_expense_POST : Testcase {
    my ($self, $oid)=@_;
    my $exp=Expense->new($oid);
    isa_ok($exp, 'Expense');

    my $record=unbless $exp;
    $record->{code}=5;
    my $request=POST("/expense/$oid", 
		     'Content-type' => 'application/json',
		     Content=>to_json($record),
	);
    my $res=request $request;
    ok ($res->is_success) or return;
    my $content=$res->content;
    my $record2=from_json($content);
    $record->{_id}=bless $record->{_id}, 'MongoDB::OID';
    $record2->{_id}=bless $record2->{_id}, 'MongoDB::OID';
    is_deeply($record, $record2, 'round trip successful');
}

__PACKAGE__->_init;
__PACKAGE__->meta->make_immutable;

1;
