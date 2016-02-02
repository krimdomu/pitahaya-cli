package Pitahaya::CLI::Cmd::Initialize;

use Moo;
use MooX::Cmd;

use MooX::Options;

use Pitahaya::API;
use Digest::SHA256;
use IO::All;

use File::Basename 'dirname';

use Data::Dumper;

option 'url' => (
  is       => 'ro',
  format   => 's',
  required => 1,
  doc      => 'URL to Pitahaya server',
);

option 'user' => (
  is       => 'ro',
  format   => 's',
  required => 1,
  doc      => 'User to use for querying api',
);

option 'password' => (
  is       => 'ro',
  format   => 's',
  required => 1,
  doc      => 'Password to use for querying api',
);

option 'site_name' => (
  is       => 'ro',
  format   => 's',
  required => 1,
  doc      => 'Which site to syncronize',
);

sub execute {
  my ( $self, $args_ref, $chain_ref ) = @_;

  mkdir ".pitahaya";
  open( my $fh, ">", ".pitahaya/config" ) or die($!);
  print $fh JSON::XS::encode_json(
    {
      url       => $self->url,
      user      => $self->user,
      password  => $self->password,
      site_name => $self->site_name,
    }
  );
  close($fh);
}

1;
