package Expense;
use Moose;
extends qw(Mongoid);
use MooseX::ClassAttribute;
use Moose::Util::TypeConstraints;

use Data::Dumper;
use DateTime;
use PhonyBone::FileUtilities qw(warnf);
use Codes;

has date =>     (is=>'ro', required=>1, 
		 isa=>subtype(as 'Str', where {m|\d\d?/\d\d?/\d\d+|}));
has cheque_no => (is=>'ro', required=>0,
		  isa=>subtype(as 'Int', where {$_[0] >= 0}));
has bank_desc => (is=>'ro', required=>1, isa=>'Str');
has amount =>   (is=>'ro', required=>1, isa=>'Num');
has code =>     (is=>'rw', required=>1);
has month =>    (is=>'ro', isa=>'Int', required=>1);
has day =>      (is=>'ro', isa=>'Int', required=>1);
has year =>     (is=>'ro', isa=>'Int', required=>1);
has ts =>       (is=>'ro', isa=>'Int', required=>1); # actually constructed in BUILDARGS; not at all sure this is the best way to do it.

class_has 'db_name' => (is=>'rw', isa=>'Str', default=>'money');
class_has 'collection_name' => (is=>'rw', isa=>'Str', default=>'budget');

# Delay loading codes as long as possible
class_has codes => (is=>'ro', isa=>'Codes', lazy=>1, builder => '_get_codes');
sub _get_codes { Codes->instance }
		    
class_has field_order => (is=>'ro', isa=>'ArrayRef',
			  default=>sub { [qw(date cheque_no bank_desc amount 
					     code month day year ts)] });
class_has int_fields => (is=>'ro', isa=>'ArrayRef',
			 default=>sub { [qw(code month day year ts)] });
class_has dbl_fields => (is=>'ro', isa=>'ArrayRef',
			 default=>sub { [qw(amount)] });


use parent qw(Exporter);
our @EXPORT_OK=qw(remove_quotes_array);

use Readonly;


around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
#    warnf "Expense::BUILDARGS: args (%d): %s", scalar @_, Dumper(\@_) if $ENV{DEBUG};

    my %args;
    if (@_ == 1) {
	my $args=$_[0];
	if (! ref $args) {
	    $args=[split(',',$args)];
	}
#	warn "args are ", Dumper($args);

	if (ref $args eq 'ARRAY') {
	    remove_quotes_array($args);

	    # merge amount fields: (the regex breaks on quoted lines)
	    my $i=$args->[3] =~ /^-?\d+[.\d]*$/? 4:3;
#	    warnf "i=%d (%s), args=%s", $i, $args->[7-$i], Dumper($args);
	    splice(@$args, $i, 1);

	    my @fo=@{$class->field_order};
	    @args{@fo}=@$args;
#	    warn "args are now ", Dumper(\%args);
	} elsif ($args eq 'HASH') {
	    %args=%{$args};
	} else {
	    confess "huh???", Dumper($args), ' '; # trailing ' ' to force stack trace
	}
	
	$args{code}=0+$args{code};
		 
    } else {
	local $SIG{__WARN__} = sub {confess @_};
	%args=@_;
    }

#    remove_quotes_hashkeys(\%args);

    $args{cheque_no} ||= ($args{check_no} || 0);
    $args{code}||=Codes->UNKNOWN;
#    warn "args now ", Dumper(\%args) if $ENV{DEBUG};

    # expand date:
    if (my $date=$args{date}) {
	my ($m,$d,$y)=split('/', $date);
	@args{qw(month day year)}=split('/', $date);
	$args{year}+=2000 unless $args{year}>2000;
	$args{ts}=DateTime->new(day=>$d, month=>$m, year=>$y)->epoch();

    }
    return $class->$orig(%args);
};




sub remove_quotes_array {
    my ($array)=@_;
    foreach my $e (@$array) {
	$e=~s/^['"]|["']$//g;
    }
}

sub remove_quotes_hashkeys {
    my $args=shift;
    my @keys=keys %$args;
    foreach my $f (@keys) {
	if (defined $args->{$f}) {
	    my $old=$args->{$f};
	    $args->{$f}=~s/^\"(.*)\"$/$1/;
	    warnf "converted '$old' to '%s'", $args->{$f};
	}
	warn "\n";
    }
}

use overload '""' => \&as_string;
sub as_string {
    my ($self)=@_;
    my $codes=$self->codes;
    my $code=$self->codes->get($self->code) or 
	die "Unknown code for ", $self->code;
    my $desc=$self->bank_desc;
    if (my $cheque_no=$self->cheque_no) {
	$desc .= " $cheque_no";
    }
    sprintf("%10s | %-75s | %8.2f | %s", 
	    $self->date, $desc, $self->amount, $code);
}

sub is_inquiry  { shift->bank_desc =~ /inquiry/i }
sub is_transfer { shift->bank_desc =~ /online banking transfer/i }

sub month_key {
    my ($self)=@_;
    join('/', $self->month, $self->year);
}

########################################################################

# class method to assign codes to any expense in the db with an
# unknown code but a desc that matches a regex:
# returns the number of records updated
sub regex2code {
    my ($class, $codes, $regexes)=@_;

    my $cursor=$class->collection->find({code => $codes->UNKNOWN});
    my $n_saved=0;
    while ($cursor->has_next) {
	my $r=$cursor->next;
	my $expression=$class->new(%$r);
	my $desc=$expression->bank_desc or next; # should always be there
	while (my ($c, $re)=each %$regexes) {
	    next unless $desc=~/$re/;
	    $expression->{code}=int($c);
	    $class->collection->save($expression, {safe=>1});
	    $n_saved++;
	    warnf "code match: %s\n", expense2string($r, $codes) if $ENV{DEBUG};
	}
    }
    warn "$n_saved codes assigned via regexs\n";
    $n_saved;
}

########################################################################

# does this Expense already exist in the db?
# Do a lookup based on date, amount, and description (but NOT code)
# returns the found record, or undef
sub has_dup_in_db {
    my ($self)=@_;
    my $query={date=>$self->date, amount=>$self->amount, bank_desc=>$self->bank_desc};
    my $record=$self->mongo->find_one($query);
}


# remove expenses that have already been entered in the db
# special handling for CODE: 
# if $exp->[CODE]=UNKNOWN 
#        and 
# $record->{code} != UNKNOWN 
#        then 
# drop $exp
# 
# return the list of $exp's not already in the db
# (class method; $self not used)
sub remove_existing {
    my ($self, $expenses)=@_;
    my @e2 = grep {! $_->has_dup_in_db} @$expenses;
    \@e2;
}

1;

