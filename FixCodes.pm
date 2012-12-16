package FixCodes;
use Carp;
use Data::Dumper;
use namespace::autoclean;
use PhonyBone::FileUtilities qw(warnf);
use Text::Autoformat;

use Moose;

has 'codes' => (is=>'ro', isa=>'Codes', default=>sub {Codes->instance->load});

sub fix_lc {
    my ($self, $options)=@_;
    my $codes=$self->codes;
    my $stats={};

    while (my ($code, $desc)=each %{$codes->codes}) {
	my $formatted = autoformat $desc, { case => 'highlight' };
	$formatted=~s/\n+$//;
	next if $formatted eq $desc;
	warnf "%2d: '%s'\n    '%s'\n", $code, $desc, $formatted if $options->{v};
	
	# handle 'dup' codes:
	if (my $dup_code=$codes->get_inv($formatted)) {
	    $stats->{conflicts}++;
	    warn "code conflict: code=$code ($desc), dup_code=$dup_code($formatted)\n" if $options->{v};
	    # find all Expenses w/code=$code, change their code to $dup_code
	    my $exps=Expense->find({code=>$code});
	    my $n_exps=scalar @$exps;
	    $stats->{exps_updated}+=$n_exps;
	    warnf "found %d expenses w/code=$code (%s)\n", $n_exps, $codes->get($code) if $options->{v};
	    # would have been faster to use Expense->update({code=>$code}, {'$set'=>{code=>$dup_code}}, {multiple=>1})
	    my $info=Expense->update({code=>$code}, {'$set'=>{code=>$dup_code}}, {multiple=>1}) unless $options->{dryrun};
	    warnf "updated %d expenses: code %d->%d (%s->%s)\n", $info->{n}, $code, $dup_code, $desc, $formatted if $options->{v};
	    
	    # remove dup code
	    $codes->mongo->remove({desc=>$desc}) unless $options->{dryrun};
	    warnf "code %d (%s) removed\n", $code, $desc if $options->{v};

	} else {
	    # Update $code: $desc <= $formatted
	    my $info=$codes->update({desc=>$desc}, # 'where'
				    {'$set'=>{desc=>$formatted}}, # fields/object to update
				    {safe=>1, multiple=>1}) unless $options->{dryrun}; # options
					   
	    $stats->{changed}++;
	    warn "Changed '$desc' to '$formatted'\n" if $options->{v};
	}
    }
    return $stats;
}

sub add_ts {
    my ($self, $options)=@_;
    my $mongo=Expense->mongo;
    my @expenses=$mongo->find->all;
    my $stats={n_expenses=>scalar @expenses};
    my $fuse=$options->{fuse};
    foreach my $exp (@expenses) {
	last if $fuse--==0;
	if ($exp->{ts}) {
	    $stats->{n_skipped}++;
	    next;
	}
	my $exp=Expense->new(%$exp);
	$exp->save;
	$stats->{n_saved}++;
	warnf "%s -> %d\n", $exp->date, $exp->ts;
    }
    $stats;
}

# make sure all codes in Codes are stored as ints in db:
sub t2i {
    my ($self, $options)=@_;
    my $mongo=$self->codes->mongo;
    my $cursor=$mongo->find;
    while ($cursor->has_next) {
	my $rec=$cursor->next;
	$rec->{code}=int($rec->{code});
	my $rep=$mongo->save($rec, {safe=>1});
	warn Dumper($rep) if $rep->{err};
    }
}

# prune expense objects based on timestamp in oid:
sub prune {
    my ($self, $options)=@_;
    my $start_ts=$options->{start_ts} || 0;
    my $stop_ts=$options->{stop_ts} || time;
    warnf "start_ts: %d\tstop_ts: %d\n", $start_ts, $stop_ts;

    sub is_between {
	my ($a,$b,$c)=@_;
	return $a<=$b && $b<$c;
    }

    # not sure how to search on oid ts, so get 
    # everything and delete as we go:
    my $exps=Expense->find;
    my $stats={total_exps=>scalar @$exps};
    my @to_delete;
    foreach my $exp (@$exps) {
	my $ts=$exp->oid_ts;
	my @lt=localtime $ts;
	my $remove=is_between($start_ts, $ts, $stop_ts);
	warnf "%d/%d/%d (%d): %s\n", $lt[3], $lt[4], 2000+$lt[5], $ts,
	    ($remove? 'remove' : 'keep') if $ENV{DEBUG};
	    
	push @to_delete, $exp if $remove;
    }
    warnf "about to remove %d expenes %s\n", scalar @to_delete,
    ($options->{dryrun}? '(not)' : '');
    $stats->{deleted}=$options->{dry_run}? 0 : scalar @to_delete;
    unless ($options->{dry_run}) {
	do {$_->delete} for @to_delete;
    }
    $stats;
}


__PACKAGE__->meta->make_immutable;

1;
