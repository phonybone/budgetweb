package InteractiveCodes;
use Moose;
use Carp;
use Data::Dumper;
use namespace::autoclean;
use English;
use Codes;
use Report;
use PhonyBone::FileUtilities qw(warnf);

# Loop through all $exp's
sub loop {
    my ($self, $expenses, $codes)=@_;
    foreach my $exp (grep {$_->code == Codes->UNKNOWN} @$expenses) {
	my $newcode=$self->loop1($exp, $codes);
	last if $newcode eq 'q';
	next if $newcode eq 's';
	$exp->code($newcode);
	$exp->save;
    }
}

# Loop through one $exp
# Prints list of codes on input '?'
# returns 'q' or 's' on those inputs (quit and skip, respectively)
# Handles insertion of new codes
# returns $code.
sub loop1 {
    my ($self, $exp, $codes)=@_;
    local $OUTPUT_AUTOFLUSH=1;

    while (1) {
	print "\n$exp\n";
	print "Enter Code ('?' for list): ";
	my $code=<STDIN>;
	chomp $code;

	if ($code eq '?') {
	    printf "%s\n", $codes->show;
	    next;
	}

	return $code if (lc $code eq 'q');
	return $code if (lc $code eq 's');
	
	# known numeric code entered:
	if ($codes->get($code)) {
	    return $code;
	}

	# known code desc:
	if (my $n_code=$codes->get_inv($code)) {
	    return $n_code;
	}

	# new code desc:
	warn "adding new code '$code'";
	my $new_code=eval {$codes->add($code)};
	if ($@) {
	    warn $@;
	    next;
	}
	warn "new code: $new_code -> $code\n" if $ENV{DEBUG};
	return $new_code;
    }
}


1;
