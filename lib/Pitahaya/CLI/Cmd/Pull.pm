package Pitahaya::CLI::Cmd::Pull;

use Moo;
use MooX::Cmd;

use JSON::XS;
use MooX::Options;

use Pitahaya::API;
use Digest::SHA256;
use IO::All;

use File::Basename 'dirname';

use Data::Dumper;

has app => ( is => 'rwp', );

sub execute {
  my ( $self, $args_ref, $chain_ref ) = @_;

  my $app = $self->command_chain->[0];
  $self->_set_app($app);

  my $cfg = $self->app->config;

  my $site_o    = $app->get_site( $cfg->{site_name} );
  my $root_page = $site_o->get_page( $site_o->root_page_id );
  $self->app->update_page( $root_page, "." );
  $self->_walk_children( $root_page, "." );

  $self->_generate_sha_db;
}

sub _walk_children {
  my ( $self, $page_o, $path ) = @_;

  for my $child_o ( $page_o->children ) {
    $self->app->update_page( $child_o, $path );
    $self->_walk_children( $child_o, $path . "/" . $child_o->url );
  }
}

sub _generate_sha_db {
  my ($self) = @_;

  my $db = $self->command_chain->[0]->get_sha_sums;

  open( my $db_fh, ">", ".pitahaya/sha.db" ) or die($!);
  print $db_fh JSON::XS::encode_json($db);
  close($db_fh);
}

1;
