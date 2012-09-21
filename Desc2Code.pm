package Desc2Code;
use PhonyBone::FileUtilities qw(file_lines);
use namespace::autoclean;

use Moose;

has 'regex_file' => (is=>'ro', isa=>'Str', required=>1);
has 'desc2code' => (is=>'ro', isa=>'HashRef', lazy=>1, builder=>'_read_regexes');

sub _read_regexes {
    my ($self)=@_;
    my $c2r={};

    foreach my $line (file_lines($self->regex_file, chomp=>1)) {
	my ($code, $regex)=split(': ', $line);
	$c2r->{$regex}=$code;
    }    
    warn scalar keys %$c2r, " regexes loaded\n";
    $c2r;
}

sub code_for {
    my ($self, $desc)=@_;
    while (my ($re, $code)=each %{$self->desc2code}) {
	return $code if $desc =~ /$re/;
    }
    undef;
}

__PACKAGE__->meta->make_immutable;

1;
