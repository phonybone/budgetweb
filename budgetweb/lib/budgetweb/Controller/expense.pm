package budgetweb::Controller::expense;
use Moose;
use namespace::autoclean;
use Expense;

BEGIN { extends 'Catalyst::Controller::REST'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->response->body('Matched budgetweb::Controller::expense in expense.');
}

sub base : Chained('/') PathPart('expense') CaptureArgs(1) {
    my ($self, $c, $oid)=@_;
    Codes->initialize();
    my $codes=Codes->instance->load;
    my $expense=eval {Expense->new($oid)};
    if ($@) {
	$self->status_not_found($c, message=>"Unable to locate expense: oid=$oid");
	$c->detach;
    }
    $c->stash->{expense}=$expense;
}

sub edit : Chained('base') {
    my ($self, $c)=@_;
    $c->stash->{template}='edit_expense.tt';
    $c->forward('View::HTML');
}

__PACKAGE__->meta->make_immutable;

1;
