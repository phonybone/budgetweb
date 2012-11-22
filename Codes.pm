package Codes;
use PhonyBone::FileUtilities qw(warnf dief);
#use Mongoid qw(get_mongo ensure_indexes);	# can't extend Mongoid; doesn't fit that model

use MooseX::Singleton;
use MooseX::ClassAttribute;

use Carp;
use Data::Dumper;
use namespace::autoclean;

has 'codes' => (is=>'ro', isa=>'HashRef', default=>sub{{}});
has 'inv_codes' => (is=>'rw', isa=>'HashRef', default=>sub{{}});

#has 'collection' => (is=>'ro', isa=>'MongoDB::Collection', lazy=>1, builder=>'_get_collection');
has 'loaded' => (is=>'rw', isa=>'Int', default=>0);
has 'reload' => (is=>'ro', isa=>'Int', default=>0);
has 'append' => (is=>'ro', isa=>'Int', default=>0);
has 'code_file' => (is=>'ro', isa=>'Str');

# the value of the next unassigned
has 'next_code' => (is=>'rw', isa=>'Int', lazy => 1, builder=>'_build_next_code');
has 'n_cols' => (is=>'ro', default=>3);


class_has 'IGNORE' => (is=>'ro', default=>-1);
class_has 'UNKNOWN' => (is=>'ro', default=>-2);

class_has 'db_name'         => (is=>'rw', isa=>'Str', default=>'money');
class_has 'collection_name' => (is=>'rw', isa=>'Str', default=>'codes');
class_has indexes => (is=>'ro', isa=>'ArrayRef', default=>sub{
    [
     {keys=>['code'], opts=>{unique=>1}},
    ]}
    );
with 'Mongoid';

sub _get_collection {
    my ($self)=@_;
    get_mongo($self->db_name, $self->collection_name);
}



# initialize $self with code/desc pairs
# read from file $self->code_file if $self->reload
sub load {
    my ($self)=@_;

    return $self if $self->loaded && !$self->reload;
    my $class=ref $self || $self;
    ensure_indexes($class, $class->indexes);

    if ($self->reload) {
	unless ($self->append) {
	    my $report=$self->mongo->remove({}, {safe=>1});
	    warn "Codes::(re)load: removed %d old codes", $report->{n} if $ENV{DEBUG};
	}
	my $codes=do $self->code_file or dief "error reading %s: $!\n", $self->code_file;
	while (my ($code,$desc)=each %$codes) {
	    $self->add($code, $desc);
	}
    } else {
	# load codes from db:
	$self->codes->{$_->{code}}=$_->{desc} for ($self->mongo->find->all);
	# Can't call $self->add because it tries to save new codes
	$self->codes->{-1}='Ignore';
	$self->codes->{-2}='Unknown';
    }

    my %inv_codes;
    $inv_codes{$self->codes->{$_}}=$_ for grep /^-?\d+$/, keys %{$self->codes};
    $self->inv_codes(\%inv_codes);
    $self->loaded(1);
    $self;
}

sub n_codes {
    my ($self)=@_;
    scalar grep /^-?\d+$/, keys %{$self->codes};
}

sub _build_next_code {
    my ($self)=@_;
    my $cursor=$self->mongo->find->sort({code=>-1})->limit(1);
    my $_next_code=$cursor->has_next? $cursor->next->{code}+1 : 1;
    warn "max _next_code2 is $_next_code";
    $_next_code;
}

sub inc_next_code {
    my ($self)=@_;
    warn "inc_next_code called";
    my $nc=$self->next_code;
    $self->next_code($nc+1);
    $nc;
}


# Return the code's description:
sub get {
    my ($self, $code)=@_;
    confess "codes not loaded" unless $self->loaded;
    $self->codes->{$code};
}

sub get_inv {
    my ($self, $desc)=@_;
    $self->inv_codes->{$desc};
}

# add a code/desc pair; if no code given, use next highest available code
# writes to the db
# return new numeric code
sub add {
    my ($self, $code, $desc)=@_;

    # if we're adding a code desc, it'll be defined as $code
    # and $desc won't be defined; hence, switch and use next_code:
    my $inc_flag=0;
    if (! defined $desc) {
	$desc=$code;
	$code=$self->next_code;	# don't inc here, we haven't checked yet for dups
	$inc_flag=1;		# there are less hacky ways to do this
	warn "Codes::add: only got desc '$desc', created new code $code";
    }

    # insure $code is numeric:
    die "code '$code' not numeric\n" unless $code=~/^[-]?\d+$/;

    # insure $desc is not numeric:
    die "code description '$desc' not allowed to be numeric\n"
	if $desc =~ /^-?\d+$/;

    # check for dups:
    if (my $desc=$self->codes->{$code}) {	
	die "Codes::add($code, $desc): already exists ($code)\n";
    }
    if (my $code=$self->inv_codes->{$desc}) {
	die "Codes::add($desc): already exists ($code)\n";
    }

    # now we can add the $code and $desc:
    $self->codes->{$code}=$desc;
    $self->inv_codes->{$desc}=$code;
    my $icode=$code+0;		# ensure it's an int
    warn "add: about to save { $icode=>$desc }";
    my $report=$self->mongo->save({code=>$icode, desc=>$desc}, {safe=>1});
    $self->inc_next_code if $inc_flag;
    $code;
}

# Display all the codes
sub show {
    my ($self)=@_;
    $self=$self->instance unless ref $self;
    # Sort codes alphabetically: 

    my @numkeys=grep /^\d+$/, keys %{$self->codes};
    my @sorted_descs=sort map {$self->codes->{$_}} @numkeys; # grep /^\d+$/, keys %$self;
    my $n_rows=int((scalar @sorted_descs)/$self->n_cols);

    my @report;
    for (my $i=0; $i<$n_rows; $i++) {
	my @line;
	for (my $j=0; $j<3; $j++) {
	    my $index=$j * $n_rows + $i;
	    my $desc=$sorted_descs[$index] or warn "no desc for index=$index\n";
	    my $code=$self->inv_codes->{$desc} or warn "no code for '$desc'\n";
	    push @line, sprintf("%-30s %3d ", $desc, $code);
	}
	push @report, join(' | ', @line);
    }
    join("\n", @report);
}

__PACKAGE__->meta->make_immutable;

1;
