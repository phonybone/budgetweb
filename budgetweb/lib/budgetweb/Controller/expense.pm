package budgetweb::Controller::expense;
use Moose;
use namespace::autoclean;
use Expense;
use Codes;
use Data::Dumper;
use PhonyBone::FileUtilities qw(warnf);
use DateTime;
use Report;

BEGIN { extends 'Catalyst::Controller::REST'; }

# This produces 'deprecated' warnings; 
# Please see 'CONFIGURATION' in Catalyst::Controller::REST.
#__PACKAGE__->config->{'serialize'}->{'default'} = 'text/x-yaml';    

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

# Last line was added to magically prevent an exception.  The exception 
# was "can't call method 'codes' on unbless reference".  Commenting
# out the string overload in Expense also caused the exception to go away,
# and this is how it was left.
# Very. Weird.
}

sub expense_POST {
    my ($self, $c)=@_;

    # retrieve server exp and client exp data:
    my $server_exp=$c->stash->{expense} or die "wtf??? no stash->{expense}";
    my $client_exp_data=$c->req->data or 
	return $self->status_bad_request($c, message=>"No data supplied");
    $client_exp_data->{cheque_no}=0 if $client_exp_data->{cheque_no} eq 'xxx';
    $c->log->debug("exp_POST: cli_exp_data is ".Dumper($client_exp_data));

    # check oid's match:
    my $cli_oid=$client_exp_data->{_id}->{'$oid'};
    my $ser_oid=$server_exp->_id->{value};
    unless ($cli_oid eq $ser_oid) {
	my $msg=sprintf("oids don't match: (client_data) '%s' vs (server/url) '%s'", 
			Dumper($cli_oid),
			Dumper($ser_oid));
	return $self->status_bad_request($c, message=>$msg);
    }

    # if no client code provided, but client desc present,
    # look up desc or create a new code as necessary:
    unless ($client_exp_data->{code}) {
	my $new_desc=$client_exp_data->{new_desc} or do {
	    my $msg="no code and no new_desc";
	    return $self->status_bad_request($c, message=>$msg);
	};
	my $codes=Codes->instance->load;
	unless ($codes->get_inv($new_desc)) {
	    my $new_code=eval{$codes->add($new_desc)};
	    if ($@) {
		my $msg="Error adding new code: $@";
		return $self->status_bad_request($c, message=>$msg);
		# fixme: handle this better somehow
	    }
	    $client_exp_data->{code}=$new_code;
	    $c->log->debug("new_code is $new_code, new_desc is $new_desc");
	} else {
	    $c->log->debug("desc '$new_desc' already exists");
	}
    } else {
	$c->log->debug('exp code predefined: '.$client_exp_data->{code});
    }
   
    # update Expense and save:
    $server_exp->code($client_exp_data->{code});
    $server_exp->save;
    $self->status_ok($c, entity=>$client_exp_data);

}

# Return the HTML to edit an expense:
sub edit_expense : Chained('base') {
    my ($self, $c)=@_;
    warn "edit called";
    $c->stash->{template}='edit_expense.tt';
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
    my $cursor=Expense->mongo->find({code=>Codes->UNKNOWN})->sort({ts=>1});
    my @records=$cursor->all;
#    do {
#	$_->{code_desc}='Unknown';
#	$_->{cheque_no}||='xxx';
#    } for @records;
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

# add a new code/desc:
sub codes_POST {
    my ($self, $c)=@_;
    my $new_desc=$c->req->data->{new_desc};
    $c->log->debug("codes_POST: new_desc is $new_desc");
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

    $c->log->debug("adding $new_desc");
    my $new_code=$codes->add($new_desc);
    return $self->status_ok($c, entity=>{code=>$new_code,
					 desc=>$new_desc});
}

sub report : Path('report') ActionClass('REST') {}
# Return a report based on request args
# Report is currently HTML based on Report.pm
sub report_POST {
    my ($self, $c)=@_;
    # args should be: start, end, and [optional] code
    # if code is present, issue a line report
    # otherwise, issue a table report
    my %args;
    $args{$_}=$c->request->params->{$_} for qw(start stop);
    unless ($args{start} && $args{stop}) {
	my $msg="missing start and/or stop";
	return $self->status_bad_request($c, message=>$msg);
    }
    unless ($args{start}=~m|\d\d/\d\d/\d\d\d\d| &&
	$args{stop}=~m|\d\d/\d\d/\d\d\d\d|) {
	my $msg="bad format for start or stop";
	return $self->status_bad_request($c, message=>$msg);
    }
    my $code_desc=$c->request->params->{code_desc};
    if ($code_desc ne '?') {	# FIXME: literal '?' is an abomination
	my $codes=Codes->instance->load;
	my $code=$codes->get_inv($code_desc);
	if ($code && $code > 0) {
	    $args{code}=$code;
	} else {
	    my $msg="bad code '$code_desc'";
	    return $self->status_bad_request($c, message=>$msg);
	}
    }
    my $report=new Report(%args);
    my $report_text = defined $report->code? $report->line_report : $report->table_report;
    $c->stash->{report_text}=$report_text;
    $c->stash->{report}=$report;
    $c->stash->{template}='report.tt';
    $c->response->content_type('text/html; charset=utf-8');
    $c->forward('View::HTML');
}

sub _table_report {
    my ($self, $cursor)=@_;
}

sub _line_report {
    my ($self, $cursor)=@_;
}

sub upload : Local {
    my ($self, $c, @args)=@_;
    $c->log->debug('upload called');
    my $uploads=$c->request->uploads; # hashref
    while (my ($form_input_name, $upload)=each %$uploads) {
	$c->log->debug(sprintf "filename: %s (%s), size: %d", 
	    $upload->filename, $upload->type, $upload->size)
    }

    $c->forward('View::HTML');
}

__PACKAGE__->meta->make_immutable;

1;

__END__
    $c->log->debug(sprintf "report: c->request->data are %s",
		   Dumper($c->request->data));
    $c->log->debug(sprintf "report: request->%s is %s", $_, 
		   eval {Dumper($c->request->$_)} || $@)
	for qw(arguments args content content_length data body input param params parameters query_parameters query_params);
