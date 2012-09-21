package ReportView;
use Moose;
use Report;

has report => (is=>'ro', isa=>'Report', required=>1);

