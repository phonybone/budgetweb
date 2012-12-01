package budgetweb::config;
use namespace::autoclean;
use Moose;

has '_data' => (is=>'ro', isa=>'HashRef', lazy=>1, builder=>'_build_data');
sub _build_data {
    my ($self)=@_;
    my $data={
	regex_file=>'/home/victor/Dropbox/sandbox/perl/money/regexes',
    };
    $data;
}

sub get {
    my ($self, $key)=@_;
    $self->_data->{$key};
}

__PACKAGE__->meta->make_immutable;

1;
