package QueryGenerator;
use Moose;
use Term::ReadLine;
use FileHandle;
use Data::Dumper;
use Carp;
use PhonyBone::FileUtilities qw(warnf dief);

has 'code' =>       (is=>'rw', isa=>'Int');

has 'start_day' =>  (is=>'rw', isa=>'Int');
has 'start_mon' =>  (is=>'rw', isa=>'Int');
has 'start_year' => (is=>'rw', isa=>'Int');

has 'stop_day' =>  (is=>'rw', isa=>'Int');
has 'stop_mon' =>    (is=>'rw', isa=>'Int');
has 'stop_year' =>   (is=>'rw', isa=>'Int');

has 'read' => (is=>'ro', isa=>'Str', default=>'-');
has 'fh' => (is=>'rw', isa=>'FileHandle');
has 'query' => (is=>'rw', isa=>'HashRef', default=>sub{{}});

# Query keys: start, 

# Expand {start} and {stop} entries into m/d/y
# "writes" to $args{query}
# inits $args{read} and $args{fh} with defaults
around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my %args=@_;
    if ($args{start}) {
	my @parts=split('/', $args{start});
	@parts and $args{start_mon}=shift @parts;
	@parts and $args{start_day}=shift @parts;
	@parts and $args{start_year}=shift @parts;
	$args{query}->{start}=$args{start};
    }
    if ($args{stop}) {
	my @parts=split('/', $args{stop});
	@parts and $args{stop_mon}=shift @parts;
	@parts and $args{stop_day}=shift @parts;
	@parts and $args{stop_year}=shift @parts;
	$args{query}->{stop}=$args{stop};
    }
    $args{query}->{code}=$args{code} if defined $args{code};

    return $class->$orig(%args);
};

sub BUILD {
    my ($self)=@_;
    my $fh=FileHandle->new($self->read) or dief "Can't open %s: %s", $self->read, $!;
    $self->fh($fh) 
}

sub date2str {
    my ($self, $which)=@_;
    my $s=join("/", grep /./, map {$self->{"${which}_$_"} || ''} qw(mon day year));
}

sub prompt {
    my ($self)=@_;
    sprintf "start: %-10s stop: %-10s: code: %s: ", 
    $self->query->{start} || '-',
    $self->query->{stop}  || '-',
    $self->query->{code}  || '-';
}


sub readline {
    my ($self, $line)=@_;
    return $line if defined $line;
    my $fh=$self->fh;
    <$fh>;
}

# generates and returns hashes representing queries
# returns the current query on each calling
sub next {
    my $self=shift;
    my $l=shift;		# may be undef
    my $fh=$self->fh;

    my $date_re=q|\d\d?/\d\d?(/\d\d)?|;

    local $_=$self->readline($l);
    chomp;
    /^g/i and do {
	$self->fix_year('start');
	$self->fix_year('stop');
	return $self->query;
    };
    /^q/i and return undef;	# quit

    # delete code, start, or stop (e);
    /^c$/ and do { delete $self->query->{code} };
    /^s$/ and do { delete $self->query->{start} };
    /^e$/ and do { delete $self->query->{stop} };

    # 'c': set code
    /^c(\d+)/ and do {
	$self->query->{code}=$1;
    };
    
    # 's': set start
    m|^s($date_re)| and do {
	$self->query->{start}=$1;
    };

    # 'e': set stop
    m|^e($date_re)| and do {
	$self->query->{stop}=$1;
    };

    $self->fix_year('start');
    $self->fix_year('stop');
    $self->query;
}

sub fix_year {
    my ($self, $which)=@_;
    my $query=$self->query;
    my $date=$query->{$which} or return;
    my @stuff=split('/', $date);
    my $year=pop @stuff;	# could be 2 or three things in @stuff
    $year+=2000 if $year && $year < 2000;
    push @stuff, $year;
    $date=join('/', @stuff);
    $query->{$which}=$date;
}
1;
