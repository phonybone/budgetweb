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
#    $c->log->debug(sprintf "test/report: request jfds is %s", Dumper($c->request));
#    $c->stash->{dump}=Dumper($c->request);
    
    $c->add_css('/jquery-ui.css');
    $c->add_js_script('/jquery-1.8.2.js');
    $c->add_js_script('/jquery-ui.js');
    $c->forward('View::HTML');
}

__PACKAGE__->meta->make_immutable;

1;
