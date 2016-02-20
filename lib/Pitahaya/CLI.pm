package Pitahaya::CLI;
use IO::All;
use Moo;
use MooX::Cmd;
use Digest::SHA256;
use Pitahaya::API;

use File::Basename 'dirname';

sub execute { }

sub config {
  my ($self) = @_;

  $ENV{HOME} ||= $ENV{USERPROFILE};

  my @config_locations = ( ".pitahaya/config", "$ENV{HOME}/.pitahaya/config", );

  my ($config_file) = grep { -f } @config_locations;

  if ( !$config_file ) {
    print
      "No configuration file found.\nYou have to initialize the repository first.\n";
    exit 1;
  }
  my $cfg = JSON::XS::decode_json( io($config_file)->slurp );

  return $cfg;
}

sub get_sha_sums {
  my @files = io(".")->All;
  my $db    = {};

  for my $f ( grep { $_->name !~ m/^\.pitahaya/ && -f $_->name } @files ) {
    my $digest = Digest::SHA256::new(256);
    $digest->reset;
    open( my $fh, "<", $f->name ) or die( $! . ": " . $f->name );
    $digest->addfile($fh);
    $db->{ $f->name } = $digest->hexdigest;
  }

  return $db;
}

sub get_sha_sums_cached {
  my ($self) = @_;
  my $ref = JSON::XS::decode_json( io(".pitahaya/sha.db")->slurp );
  return $ref;
}

sub get_site {
  my ($self) = @_;

  my $pit = Pitahaya::API->new(
    {
      username => $self->config->{user},
      password => $self->config->{password},
      url      => $self->config->{url},
    }
  );
  my $site_o = $pit->get_site( $self->config->{site_name} );

  return $site_o;
}

sub get_data {
  my ( $self, $file ) = @_;

  my $data = {};
  my $meta_file;
  my $content_file;

  if ( $file =~ m/\.meta\.json$/ ) {
    $meta_file    = $file;
    $content_file = $file;
    $content_file =~ s/\.meta\.json$//;

    $content_file = "$content_file.md"   if ( -f "$content_file.md" );
    $content_file = "$content_file.html" if ( -f "$content_file.html" );
  }
  else {
    $content_file = $file;
    $meta_file    = $file;
    $meta_file =~ s/\.(html|md)$//;
    $meta_file = "$meta_file.meta.json";
  }

  my $c = io($meta_file)->slurp;
  $data = JSON::XS::decode_json($c);
  $data->{content} = io($content_file)->slurp;

  return $data;
}

sub update_sha_sum {
  my ( $self, $file ) = @_;
  my $db = $self->get_sha_sums_cached;

  my $digest = Digest::SHA256::new(256);
  open( my $fh, "<", $file ) or die($!);
  $digest->addfile($fh);
  $db->{$file} = $digest->hexdigest;

  open( my $db_fh, ">", ".pitahaya/sha.db" ) or die($!);
  print $db_fh JSON::XS::encode_json($db);
  close($db_fh);
}

sub remove_sha_sum {
  my ( $self, $file ) = @_;
  my $db = $self->get_sha_sums_cached;

  my $metafile     = $file;
  my $content_file = $file;

  $file =~ s/\.(html|md|meta\.json)$//;
  $metafile = "$file.meta.json";

  delete $db->{$metafile};
  delete $db->{"$file.html"};
  delete $db->{"$file.md"};

  open( my $db_fh, ">", ".pitahaya/sha.db" ) or die($!);
  print $db_fh JSON::XS::encode_json($db);
  close($db_fh);
}

sub get_page_id_cached {
  my ( $self, $file ) = @_;

  my $ref;

  my $metafile = $file;
  if ( $file !~ m/\.(meta\.json)$/ ) {
    $file =~ s/\.(html|md|meta\.json)$//;
    $metafile = "$file.meta.json";
  }

  if ( -f ".pitahaya/id.db" ) {
    $ref = JSON::XS::decode_json( io(".pitahaya/id.db")->slurp );
  }
  return $ref->{"./$metafile"} || $ref->{$metafile};
}

sub remove_page_id {
  my ( $self, $file ) = @_;

  my $ref;

  my $metafile     = $file;
  my $content_file = $file;

  $file =~ s/\.(html|md|meta\.json)$//;
  $metafile = "$file.meta.json";

  if ( -f ".pitahaya/id.db" ) {
    $ref = JSON::XS::decode_json( io(".pitahaya/id.db")->slurp );
  }

  delete $ref->{$metafile};
  delete $ref->{"$file.html"};
  delete $ref->{"$file.md"};
  delete $ref->{"./$file.html"};
  delete $ref->{"./$file.md"};

  delete $ref->{ "./" . $metafile };

  my $c = JSON::XS::encode_json($ref);
  io(".pitahaya/id.db") < $c;
}

sub update_page_id {
  my ( $self, $id, $metafile ) = @_;

  my $ref = {};

  if ( -f ".pitahaya/id.db" ) {
    $ref = JSON::XS::decode_json( io(".pitahaya/id.db")->slurp );
  }

  $ref->{$metafile} = $id;

  my $c = JSON::XS::encode_json($ref);
  io(".pitahaya/id.db") < $c;
}

sub update_page {
  my ( $self, $page, $path ) = @_;

  my $coder   = JSON::XS->new->ascii->pretty->allow_nonref;
  my $content = $page->content;
  my $content_file;
  my $meta_file;

  my %ref = %{$page};

  for my $k (
    qw/id content_type_id type_id site api rel_date site_id creator_id m_date c_date level lft rgt content /
    )
  {
    delete $ref{$k};
  }

  if ( $page->is_leaf ) {
    $meta_file    = "$path/" . $page->url . ".meta.json";
    $content_file = "$path/" . $page->url . ".";

    if ( $page->content_type_name =~ m/\/html$/ ) {
      $content_file .= "html";
    }
    if ( $page->content_type_name =~ m/\/markdown$/ ) {
      $content_file .= "md";
    }

    mkdir dirname $meta_file;

    open( my $fh, ">", "$meta_file.tmp" ) or die($!);
    print $fh $self->_make_json( \%ref );
    close($fh);

    open( $fh, ">", "$content_file.tmp" ) or die($!);
    binmode( $fh, ":utf8" );
    print $fh $content if $content;
    close($fh),;
  }
  else {
    if ( $page->level != 0 ) {
      $path .= "/" . $page->url;
    }

    mkdir "$path";

    $meta_file    = "$path/index" . ".meta.json";
    $content_file = "$path/index" . ".";

    if ( $page->content_type_name =~ m/\/html$/ ) {
      $content_file .= "html";
    }
    if ( $page->content_type_name =~ m/\/markdown$/ ) {
      $content_file .= "md";
    }

    open( my $fh, ">", "$meta_file.tmp" ) or die($!);
    binmode( $fh, ":utf8" );
    print $fh $self->_make_json( \%ref );
    close($fh);

    open( $fh, ">", "$content_file.tmp" ) or die($!);
    print $fh $content if $content;
    close($fh),;
  }

  $self->update_page_id( $page->id, $meta_file );

  if ( -f $meta_file ) {
    open( my $fh_m, "<", $meta_file ) or die($!);
    my $digest = Digest::SHA256::new(256);
    $digest->addfile($fh_m);

    open( my $fh_t, "<", "$meta_file.tmp" ) or die($!);
    my $digest_t = Digest::SHA256::new(256);
    $digest_t->addfile($fh_t);

    if ( $digest->hexdigest() ne $digest_t->hexdigest() ) {
      $self->_print_status( $meta_file, changed => 1 );
      rename "$meta_file.tmp", "$meta_file";
    }
    else {
      unlink "$meta_file.tmp";
    }
  }
  else {
    $self->_print_status( $meta_file, new => 1 );
    rename "$meta_file.tmp", "$meta_file";
  }

  if ( -f $content_file ) {
    open( my $fh_c, "<", $content_file ) or die($!);
    my $digest = Digest::SHA256::new(256);
    $digest->addfile($fh_c);

    open( my $fh_t, "<", "$content_file.tmp" ) or die($!);
    my $digest_t = Digest::SHA256::new(256);
    $digest_t->addfile($fh_t);

    if ( $digest->hexdigest() ne $digest_t->hexdigest() ) {
      $self->_print_status( $content_file, changed => 1 );
      rename "$content_file.tmp", "$content_file";
    }
    else {
      unlink "$content_file.tmp";
    }
  }
  else {
    $self->_print_status( $content_file, new => 1 );
    rename "$content_file.tmp", "$content_file";
  }
}

sub _print_status {
  my ( $self, $file, %opt ) = @_;

  print "  ";
  $self->_print_opts( "u", $opt{changed} ) if $opt{changed};
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

sub _make_json {
  my ( $self, $ref, $indent ) = @_;

  $indent ||= 0;

  my @ret;

  if ( ref $ref eq "HASH" ) {
    push @ret,
        ( " " x ($indent) ) . '{' . "\n"
      . $self->_make_json_hash( $ref, $indent + 2 ) . "\n"
      . ( " " x ($indent) ) . '}';
  }
  elsif ( ref $ref eq "ARRAY" ) {
    push @ret,
        ( " " x ($indent) ) . '[' . "\n"
      . $self->_make_json_array( $ref, $indent + 2 ) . "\n"
      . ( " " x ($indent) ) . ']';
  }

  return join( "\n", @ret );
}

sub _make_json_hash {
  my ( $self, $ref, $indent ) = @_;

  my @str;

  for my $key ( sort keys %{$ref} ) {
    my $val = $ref->{$key};
    if ( !defined $val ) {
      push @str, ( " " x $indent ) . "\"$key\": null";
    }
    elsif ( ref $val eq "HASH" ) {
      push @str,
          ( " " x ($indent) ) . '{' . "\n"
        . $self->_make_json_hash( $val, $indent + 2 ) . "\n"
        . ( " " x ($indent) ) . '}';
    }
    elsif ( ref $val eq "ARRAY" ) {
      push @str,
          ( " " x ($indent) ) . '[' . "\n"
        . $self->_make_json_array( $val, $indent + 2 ) . "\n"
        . ( " " x ($indent) ) . ']';
    }
    elsif ( $val =~ m/^\d+$/ ) {
      push @str, ( " " x $indent ) . "\"$key\": $val";
    }
    else {
      $val =~ s/"/\\"/g;
      push @str, ( " " x $indent ) . "\"$key\": \"$val\"";
    }
  }

  return join( ",\n", @str );
}

sub _make_json_array {
  my ( $self, $ref, $indent ) = @_;

  my @str;

  for my $val ( @{$ref} ) {
    if ( !defined $val ) {
      push @str, ( " " x $indent ) . "null";
    }
    elsif ( ref $val eq "HASH" ) {
      push @str,
          ( " " x ($indent) ) . '{' . "\n"
        . $self->_make_json_hash( $val, $indent + 2 ) . "\n"
        . ( " " x ($indent) ) . '}';
    }
    elsif ( ref $val eq "ARRAY" ) {
      push @str,
          ( " " x ($indent) ) . '[' . "\n"
        . $self->_make_json_array( $val, $indent + 2 ) . "\n"
        . ( " " x ($indent) ) . ']';
    }
    elsif ( $val =~ m/^\d+$/ ) {
      push @str, ( " " x $indent ) . "$val";
    }
    else {
      $val =~ s/"/\\"/g;
      push @str, ( " " x $indent ) . "\"$val\"";
    }
  }

  return join( ",\n", @str );
}

1;
