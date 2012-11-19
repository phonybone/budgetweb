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

__PACKAGE__->meta->make_immutable;

1;
