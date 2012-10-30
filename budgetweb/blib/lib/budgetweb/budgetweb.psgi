use strict;
use warnings;

use budgetweb;

my $app = budgetweb->apply_default_middlewares(budgetweb->psgi_app);
$app;

