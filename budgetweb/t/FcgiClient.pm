package FcgiClient;
use namespace::autoclean;

use Moose;
extends 'PhonyBone::TestCase';
use parent qw(PhonyBone::TestCase); # for method attrs, sigh...
use Test::More;
use Data::Dumper;
use PhonyBone::FileUtilities qw(warnf);
use FCGI::Client;
use IO::Socket::INET;

before qr/^test_/ => sub { shift->setup };

has 'host' => (is=>'ro', isa=>'Str', default=>'localhost');
has 'port' => (is=>'ro', isa=>'Int', default=>3003);
has 'client' => (is=>'ro', isa=>'FCGI::Client::Connection', lazy=>1,
		 builder=>'_build_client');
sub _build_client {
    my ($self)=@_;
    my $sock = IO::Socket::INET->new(
	PeerAddr => $self->host,
	PeerPort => $self->port,
	) or die "$!";
    
    FCGI::Client::Connection->new(sock=>$sock);
}

sub test_static : Testcase {
    my ($self)=@_;
    my ($stdout,$stderr)=$self->client->request(
	{ REQUEST_METHOD => 'GET',
	  QUERY_STRING => '/expense',
	},
	'',
	);
    print "stdout: $_" for <$stdout>;
    print "stderr: $_" for <$stderr>;
}

__PACKAGE__->meta->make_immutable;

1;
