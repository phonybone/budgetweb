package MoneyDB;
use strict;
use warnings;
use MooseX::Singleton;
use PhonyBone::FileUtilities qw(warnf);
use Desc2Code;
use InteractiveCodes;
use Expense;
use ExpenseReader;

use namespace::autoclean;

has 'codes' => (is=>'ro', isa=>'Codes', required=>1);
#has 'expenses' => (is=>'rw', isa=>'ArrayRef[Expense]');

# options:
has 'verbose' => (is=>'rw', isa=>'Int', default=>0);
has 'regex_file' => (is=>'ro', isa=>'Str');


sub load_file_expenses {
    my ($self, @files)=@_;
    my $expenses=$self->read_files(@files); # list of Expense objects

    # convert alpha codes to numbers:
    $self->alphacode2numeric($expenses);

    $expenses;
}


# read in files
# return a listref of $expenses:
sub read_files {
    my ($self, @files)=@_;
    my $n_files=0;
    my $total_expenses=0;
    my $expenses=[];
    foreach my $input_csv (@files) {
	next unless -r $input_csv;
	warn "inputing $input_csv\n" if $self->verbose;

	my $reader=new ExpenseReader(file_name=>$input_csv);
	my $exps=$reader->expenses;
	warnf "got %d expenses from %s\n", scalar @$exps, $input_csv;
	$total_expenses+=scalar @$exps;
	push @$expenses, @$exps;
	$n_files++;
    }
#    die "no files for rebuild\n" unless $n_files;

    # remove expenses with dups in the db:
    my $e2=Expense->remove_existing($expenses);
    $e2;
}


# convert alpha codes to numeric ones:
# 
sub alphacode2numeric {
    my ($self, $expenses)=@_;
    confess "no expenses" unless $expenses;
    my $codes=$self->codes;

    foreach my $expense (@$expenses) {
	my $code=$expense->code;
	next if ($codes->get($code));

	if ($code=~/^\d+$/) {	# code is unknown numeric, wtf?
	    die "Unknown numeric code $code\n"; # might do something more clever later
	}

	if (my $realcode=$codes->get_inv($code)) {
	    # known alpha code, convert to numeric value:
	    $expense->code($realcode);
	    $expense->save;
	    next;
	}

	# got a new code that is not just digits, add it:
	my $realcode=eval {$codes->add($code)};
	if ($@) {
	    warn $@;
	    next;
	}
	$expense->code($realcode);
	$expense->save;
    }
}


# \d+ to assign code or create new code
# 
# '' to show codes
# 'q' to quit
# 's' to skip (leave code assigned to UNKNOWN)
sub interactive_add_codes {
    my ($self)=@_;
    my $codes=$self->codes;
    my $expenses=Expense->find({code=>$codes->UNKNOWN});
    printf "%d records with code==UNKNOWN\n", scalar @$expenses;
    printf $codes->show, "\n";

    my $ic=new InteractiveCodes;
    $ic->loop($expenses, $codes);
}


# attempt to assign expenses with code==unknown using manually currated regexs:
# return number of expenses that get a new code assignment.
sub regex2code {
    my ($self)=@_;

    my $regex_file=$self->regex_file;
    return 0 unless $regex_file && -r $regex_file;

    my $d2c=new Desc2Code(regex_file=>$regex_file);
    my $n_assigned=0;
    my $expenses=Expense->find({code=>Codes->UNKNOWN});
    warnf "%d new expenses w/code==UNKNOWN\n", scalar @$expenses;
    foreach my $exp (@$expenses) {
	my $code=$d2c->code_for($exp->bank_desc) or next;
	$exp->code($code);
	$exp->save;
	$n_assigned++;
    }
    $n_assigned;
}

sub initial_report {
    my ($self)=@_;

    my $start=time-60*60*24*365; # 12 months ago
    my @datelist=localtime($start);
    my $start_date=sprintf "%d/%d/%d", $datelist[4], $datelist[3], $datelist[5]+1900;

    my $stop=time; # 12 months ago
    @datelist=localtime($stop);
    my $stop_date=sprintf "%d/%d/%d", $datelist[4], $datelist[3], $datelist[5]+1900;


    my $report=Report->new(start=>$start_date, stop=>$stop_date);
#    my $report=Report->new(start_ts=>$start, stop_ts=>$now);
    print $report->table_report, "\n";
}

__PACKAGE__->meta->make_immutable;
1;

