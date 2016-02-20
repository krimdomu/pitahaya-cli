package Pitahaya::CLI::Cmd::Push;

use Moo;
use MooX::Cmd;

use MooX::Options;

use Pitahaya::API;
use JSON::XS;

use File::Basename 'dirname';
use Hash::Diff qw/diff/;

use Data::Dumper;

has app => ( is => 'rwp', );

sub execute {
  my ( $self, $args_ref, $chain_ref ) = @_;

  my $app = $self->command_chain->[0];
  $self->_set_app($app);

  my $cfg       = $self->app->config;
  my $db        = $self->app->get_sha_sums;
  my $db_cached = $self->app->get_sha_sums_cached;
  my $site_o    = $self->app->get_site;

  my $diff = diff $db, $db_cached;

  my @updates;

DIFF: for my $f ( keys %{$diff} ) {
    my %opt;

    my $needs_delete;

    $needs_delete = exists $db_cached->{$f} && !exists $db->{$f};

    for my $uf (@updates) {
      my $cf = $f;
      $uf =~ s/\.(html|md|meta\.json)$//;
      $cf =~ s/\.(html|md|meta\.json)$//;

      if ( ( $uf eq $cf ) && !$needs_delete ) {
        $app->update_sha_sum($f) if ( -f $f );
        next DIFF;
      }
    }

    if ($needs_delete) {
      my $page_o = $site_o->get_page( $self->app->get_page_id_cached($f) );
      $page_o->remove;
      $app->remove_sha_sum($f);
      $app->remove_page_id($f);
      $needs_delete = 2;

      my $metafile     = $f;
      my $content_file = $f;

      $f =~ s/\.(html|md|meta\.json)$//;
      $metafile = "$f.meta.json";
      delete $db_cached->{$metafile};
      delete $db_cached->{"$f.html"};
      delete $db_cached->{"$f.md"};
    }
    elsif ( !exists $db_cached->{$f} && exists $db->{$f} ) {

      # new
      my $data = $self->app->get_data($f);
      my $parent_o;
      my $ret_o;
      if ( $f =~ m/\/index\.(html|md|meta\.json)/ ) {

        # no leaf node, use parent
        my $parent_file = dirname( dirname($f) ) . "/index.meta.json";
        $parent_o =
          $site_o->get_page( $self->app->get_page_id_cached($parent_file) );
      }
      else {
        my $parent_file = dirname($f) . "/index.meta.json";
        $parent_o =
          $site_o->get_page( $self->app->get_page_id_cached($parent_file) );
      }

      $ret_o = $parent_o->add_to_children($data);
      $app->update_sha_sum($f);

      #      $app->update_page_id($f);
    }
    elsif ( $db_cached->{$f} ne $db->{$f} ) {

      # changed
      my $data   = $app->get_data($f);
      my $page_o = $site_o->get_page( $self->app->get_page_id_cached($f) );
      $page_o->update( %{$data} );
      $app->update_sha_sum($f);
    }

    push @updates, $f;
  }
}

1;
