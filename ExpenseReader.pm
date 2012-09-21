package ExpenseReader;
use Carp;
use Data::Dumper;
use Expense;
use PhonyBone::FileUtilities qw(file_lines warnf);

use Moose;
has 'file_name' => (is=>'ro', isa=>'Str', required=>1);
has 'keep_transfers' => (is=>'ro', isa=>'Int', default=>1);
use namespace::autoclean;

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    if ( @_ == 1 && !ref $_[0]) {
	return $class->$orig( file_name => $_[0] );
    } else {
	return $class->$orig(@_);
    }
};


# read the file and return a list[ref] of Expense objects:
sub expenses {
    my ($self)=@_;
    my $filename=$self->file_name;

    my @expenses;
    open (CSV, $filename) or die "Can't open $filename: $!\n";
    while (<CSV>) {
	chomp;
	my $line=[split(',')];
#	my $line=[split(/\s*,\s*/)];
	next if ignore($line);
#	my $expense=new Expense($_);
	my $expense=eval {new Expense($_)};
	if ($@) {
	    my $msg=(split("\n", $@))[0];
	    warnf "bad line: %s\n%s\n", $_, $msg;
	    next;
	}
	next if $expense->is_inquiry;
	next if !$self->keep_transfers && $expense->is_transfer;
	push @expenses, $expense;
    }
    close CSV;
    warn sprintf("$filename: %d items\n", scalar @expenses) if $ENV{DEBUG};
    wantarray? @expenses:\@expenses;
}

    ########################################################################

sub ignore {
    my ($line)=@_;
    no warnings;
    return 1 if $line->[0] eq '"Date"' && $line->[1] eq '"No."' &&
	$line->[2] eq '"Description"' && $line->[3] eq '"Debit"' && 
	$line->[4] eq '"Credit"';	# overkill much?

    return 0;
}



__PACKAGE__->meta->make_immutable;

1;
