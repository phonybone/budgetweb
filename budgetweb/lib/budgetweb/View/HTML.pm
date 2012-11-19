package budgetweb::View::HTML;
use Moose;
use namespace::autoclean;
use POSIX qw(strftime);
extends 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    WRAPPER => 'header.tt',
    render_die => 1,
);
    

sub nice_date {
    my ($self, $ts)=@_;
    strftime("%b %d, %Y", localtime $ts);
}

sub nice_amount {
    my ($self, $amount)=@_;
    $amount=-$amount if $amount<0;
    sprintf '$%.2f', $amount;
}

has 'codes' => (is=>'ro', isa=>'Codes', default=>sub {Codes->instance});
has 'code_select' => (is=>'ro', isa=>'Str', lazy=>1, builder=>'_build_code_select');
sub _build_code_select {
    my ($self)=@_;
    my @select=("<select name='code_sel'>");
    foreach my $desc (sort {lc $a cmp lc $b} keys %{$self->codes->inv_codes}) {
	my $code=$self->codes->get_inv($desc);
	push @select, sprintf "<option value='%d'>(%d) %s</option>", 
	$code, $code, $desc;
    }
    push @select, "</select>";
    join("\n", @select);
}

=head1 NAME

budgetweb::View::HTML - TT View for budgetweb

=head1 DESCRIPTION

TT View for budgetweb.

=head1 SEE ALSO

L<budgetweb>

=head1 AUTHOR

victor,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
