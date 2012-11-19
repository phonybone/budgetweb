package budgetweb::Controller::test;
use Moose;
use namespace::autoclean;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched budgetweb::Controller::test in test.');
}

sub report :Local {
    my ($self, $c)=@_;
    $c->log->debug(sprintf "test/report: request is %s", Dumper($c->request));
    $c->stash->{dump}=Dumper($c->request);
    $c->forward('View::HTML');
}

__PACKAGE__->meta->make_immutable;

1;
