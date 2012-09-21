package QG2;
use base qw(Term::Shell);

sub run_c {
    my ($self, @args)=@_;
    printf "c: args are ", join(', ', @args), "\n";
}

1;
