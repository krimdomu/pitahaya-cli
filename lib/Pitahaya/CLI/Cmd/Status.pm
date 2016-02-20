package Pitahaya::CLI::Cmd::Status;

use Moo;
use MooX::Cmd;

use MooX::Options;

use Pitahaya::API;
use JSON::XS;

use File::Basename 'dirname';
use Hash::Diff qw/diff/;

use Data::Dumper;

sub execute {
  my ( $self, $args_ref, $chain_ref ) = @_;

  my $cfg       = $self->command_chain->[0]->config;
  my $db        = $self->command_chain->[0]->get_sha_sums;
  my $db_cached = $self->command_chain->[0]->get_sha_sums_cached;

  my $diff = diff $db, $db_cached;

  #  print Dumper $diff;
  for my $f ( keys %{$diff} ) {
    my %opt;
    if ( exists $db_cached->{$f} && !exists $db->{$f} ) {
      $opt{deleted} = 1;
    }
    elsif ( !exists $db_cached->{$f} && exists $db->{$f} ) {
      $opt{new} = 1;
    }
    elsif ( $db_cached->{$f} ne $db->{$f} ) {
      $opt{changed} = 1;
    }

    $self->_print_status( $f, %opt );
  }
}

sub _print_status {
  my ( $self, $file, %opt ) = @_;

  print "  ";
  $self->_print_opts( "c", $opt{changed} ) if $opt{changed};
  $self->_print_opts( "n", $opt{new} )     if $opt{new};
  $self->_print_opts( "d", $opt{deleted} ) if $opt{deleted};

  print "\t\t" . $file . "\n";
}

sub _print_opts {
  my ( $self, $key, $test ) = @_;

  if ($test) {
    print $key;
  }
  else {
    print " ";
  }
}

1;
