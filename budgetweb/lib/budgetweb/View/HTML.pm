package budgetweb::View::HTML;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    render_die => 1,
);

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
