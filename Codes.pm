package Codes;
use PhonyBone::FileUtilities qw(warnf dief);
use Mongoid qw(get_mongo ensure_indexes);	# can't extend Mongoid; doesn't fit that model

use MooseX::Singleton;
use MooseX::ClassAttribute;

use Carp;
use Data::Dumper;
use namespace::autoclean;

has 'codes' => (is=>'ro', isa=>'HashRef', default=>sub{{}});
has 'inv_codes' => (is=>'rw', isa=>'HashRef', default=>sub{{}});

has 'collection' => (is=>'ro', isa=>'MongoDB::Collection', lazy=>1, builder=>'_get_collection');
has 'loaded' => (is=>'rw', isa=>'Int', default=>0);
has 'reload' => (is=>'ro', isa=>'Int', default=>0);
has 'append' => (is=>'ro', isa=>'Int', default=>0);
has 'code_file' => (is=>'ro', isa=>'Str');

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

sub _get_collection {
    my ($self)=@_;
    get_mongo($self->db_name, $self->collection_name);
}

sub mongo { shift->collection }



sub BUILD_this_never_gets_call_fixme {
    confess "BUILD";
    my ($self, $options)=@_;
    $self->load(%$options);
    warn "Codes loaded\n";
}



# initialize $self with code/desc pairs
# read from file $self->code_file if $self->reload
sub load {
    my ($self, %options)=@_;

    return $self if $self->loaded && !$self->reload;
    my $class=ref $self || $self;
    ensure_indexes($class, $class->indexes);

    if ($self->reload) {
	$self->collection->delete_all unless $self->append;
	my $codes=do $self->code_file or dief "error reading %s: $!\n", $self->code_file;
	while (my ($code,$desc)=each %$codes) {
	    $self->add($code, $desc);
	}
    } else {
	$self->codes->{$_->{code}}=$_->{desc} for ($self->collection->find->all);
	# Can't call $self->add because it tries to save new codes
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

my $_next_code;
sub _build_next_code {
    my ($self)=@_;
    if (! defined $_next_code) {
	$_next_code=$self->n_codes;
    }
    warn "_bnc: returning ", $_next_code+1;
    ++$_next_code;
}

sub inc_next_code {
    my ($self)=@_;
    $self->next_code($self->next_code()+1);
}


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
# return new numeric code
sub add {
    my ($self, $code, $desc)=@_;

    # if we're adding a code desc, it'll be defined as $code
    # and $desc won't be defined; hence, switch and use next_code:
    if (! defined $desc) {
	$desc=$code;
	$code=$self->next_code;
	warn "adding new code $code=$desc\n";
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
    my $report=$self->collection->save({code=>$code, desc=>$desc}, {safe=>1});
    warn "adding $code->$desc: report is ", Dumper($report) if $ENV{DEBUG};
    $self->inc_next_code;
    $code;
}

# Display all the codes
sub show {
    my ($self)=@_;
    $self=$self->instance unless ref $self;
    # Sort codes alphabetically: 

    my @numkeys=grep /^\d+$/, keys %{$self->codes};
    warnf "%d codes\n", scalar @numkeys;
    my @sorted_descs=sort map {$self->codes->{$_}} @numkeys; # grep /^\d+$/, keys %$self;
#    warn "sorted_descs are ", Dumper(\@sorted_descs);
    my $n_rows=int((scalar @sorted_descs)/$self->n_cols);
#    warnf "%d entries, %d rows\n", scalar @sorted_descs, $n_rows;

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
