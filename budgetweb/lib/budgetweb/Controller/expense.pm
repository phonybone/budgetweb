package budgetweb::Controller::expense;
use Moose;
use namespace::autoclean;
use Expense;
use Codes;
use Data::Dumper;

BEGIN { extends 'Catalyst::Controller::REST'; }

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->response->body('Matched budgetweb::Controller::expense in expense.');
}

sub base : Chained('/') PathPart('expense') CaptureArgs(1) {
    my ($self, $c, $oid)=@_;
    if (!$oid) {
	$self->status_bad_request($c, message=>"missing oid");
	$c->detach;
    }
    eval {Codes->initialize()};
    $c->stash->{codes}=Codes->instance->load;
    my $expense=eval {Expense->new($oid)};
    if ($@) {
	$self->status_not_found($c, message=>"Unable to locate expense: oid='$oid'");
	$c->detach;
    }
    $c->stash->{expense}=$expense;
}

sub expense : Chained('base') PathPart('') ActionClass('REST') Args(0) {}
sub expense_GET {
    my ($self, $c)=@_;
    my $expense=$c->stash->{expense} or die "no expense";
    my $record=unbless $expense;
    $c->stash->{rest}=$record;
#    $c->log->debug('got here3');
# Last line was added to magically prevent an exception.  The exception 
# was "can't call method 'codes' on unbless reference".  Commenting
# out the string overload in Expense also caused the exception to go away,
# and this is how it was left.
# Very. Weird.
}

sub expense_POST {
    my ($self, $c)=@_;
    my $server_exp=$c->stash->{expense} or die "wtf??? no stash->{expense}";
    my $client_exp_data=$c->req->data or 
	return $self->status_bad_request($c, message=>"No data supplied");
    $client_exp_data->{cheque_no}=0 if $client_exp_data->{cheque_no} eq 'xxx';
    $c->log->debug('client_exp_data: '.Dumper($client_exp_data));
    my $client_exp=eval {Expense->new(%$client_exp_data)};

    # check oid's match:
    unless ($client_exp_data->{_id}->{'$oid'} eq $server_exp->_id->{value}) {
	return $self->status_bad_request($c, message=>sprintf("oids don't match: (client_data) '%s' vs (server/url) %s", 
							      $client_exp_data->{_id}->{value},
							      $server_exp->_id->{value}));
    }

    $client_exp_data->{_id}=bless $client_exp_data->{_id}, 'MongoDB::OID';
    warn "expense_POST: client_exp_data is ",Dumper($client_exp_data);
    my $new_expense=Expense->new(%$client_exp_data);
    warn "saving ", $new_expense->as_string;
    $new_expense->save;
    $self->status_ok($c, entity=>unbless $new_expense);
}

# Return the HTML to edit an expense:
sub edit_expense : Chained('base') {
    my ($self, $c)=@_;
    warn "edit called";
    $c->stash->{template}='edit_expense.tt';
    $c->stash->{dump}=Dumper($c->stash->{expense});
    $c->forward('View::HTML');
}

# Redirect to edit the next 'unknown' expense
sub edit_next : Chained('base') {
    my ($self, $c)=@_;
    my $expense=$c->stash->{expense};
    my $next_oid=$self->_get_next_oid($expense);
    my $action=$c->controller('expense')->action_for('edit');
    $c->forward(ref $self, 'edit', [[], [$next_oid]]);
}


sub _get_next_oid {
    my ($self, $expense)=@_;
    my $query={code=>Codes->UNKNOWN,
	       ts=>{'$gte', $expense->ts}};
    my $cursor=Expense->mongo->find($query)->sort({ts=>1});
    if (!$cursor->has_next) {
	# do something appropriate here:
    }
    my $record=$cursor->next;
    my $next_oid=$record->{_id} or die "no _id???";
}

# return a json array of Expense objects with code==UNKNOWN
# sort by ts
# optional limit
sub unknown : Local ActionClass('REST') {}
sub unknown_GET {
    my ($self, $c)=@_;
    my $cursor=Expense->mongo->find({code=>Codes->UNKNOWN})->limit(100)->sort({ts=>1});
    my @records=$cursor->all;
    do {
	$_->{code_desc}='Unknown';
	$_->{cheque_no}||='xxx';
    } for @records;
    $c->log->debug('records[0] '.Dumper($records[0]));
    $c->stash->{rest}={count=>$cursor->count,
		       expenses=>\@records};
}

# return the html for the entire app:
sub editor : Local {
    my ($self, $c)=@_;
    $c->stash->{template}='budget_editor.tt';
    $c->add_js_script('/jquery-1.8.2.js');
    $c->add_js_script('/jquery-ui.js');
    $c->add_js_script('/js/utils.js');
    $c->add_js_script('/js/sprintf-0.7-beta1.js');
    $c->add_js_script('/js/budget_editor.js');
    $c->add_css('/jquery-ui.css');
    $c->add_css('/css/budget_editor.css');
    $c->forward('View::HTML');
}


sub codes : Local ActionClass('REST') {}
sub codes_GET {
    my ($self, $c)=@_;
    eval {Codes->initialize};
    my $codes=Codes->instance->load;
    $c->stash->{rest}=$codes->codes; # n2desc version
}

sub codes_POST {
    my ($self, $c)=@_;
    my $new_desc=$c->req->data->{new_desc};
    unless ($new_desc) {
	my $msg="missing code and/or desc";
	return $self->status_bad_request($c, message=>$msg);
    }

    # check this code doesn't already exist:
    my $codes=Codes->instance->load;
    if (my $old_code=$codes->get_inv($new_desc)) {
	return $self->status_ok($c, entity=>{code=>$old_code,
					     desc=>$new_desc});
    }

    my $new_code=$codes->add($new_desc);
    return $self->status_ok($c, entity=>{code=>$new_code,
					 desc=>$new_desc});
}

__PACKAGE__->meta->make_immutable;

1;
