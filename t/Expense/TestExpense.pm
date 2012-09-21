package t::Expense::TestExpense;
use Moose;
use MooseX::Singleton;
use Expense;
use ExpenseReader;

has 'test_file' => (is=>'rw', isa=>'Str', required=>1);

# re-initialize the expense db:
sub setup {
    my ($self)=@_;
    Expense->db_name('test_money');
    Expense->delete_all;

    my $test_file=$self->test_file;
    my $er=new ExpenseReader(file_name=>$test_file);
    my $expenses=$er->expenses;
    $_->save for @$expenses;
    $expenses;
}

1;
