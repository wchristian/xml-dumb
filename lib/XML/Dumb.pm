use strictures;

package XML::Dumb;

=head1 DESCRIPTION

    Wat is en Dampfmaschin?

    Da stelle mer uns janz dumm. Und da sage mer so:
    En Dampfmaschin, dat is ene jroße, schwarze Raum.

        -- Lehrer Bömmel ( Feuerzangenbowle )

=cut

use Carp 'croak';
use XML::Twig;
use Moo;

sub {
    has $_ => ( is => 'ro', lazy => 1, builder => "_build_$_" ) for qw( twig );
    has $_ => ( is => 'ro' ) for qw(
      root_wrapper  children_as_keys_by_tag  children_as_keys_by_att
      atts_as_keys  only_child_as_key        element_as_only_child
    );
    has children_key => is => 'ro', default => sub { 'children' };
    has tag_key      => is => 'ro', default => sub { 'tag' };
    has atts_key     => is => 'ro', default => sub { 'atts' };
  }
  ->();

sub _build_twig { XML::Twig->new }

sub parsefile {
    my ( $self, $file ) = @_;
    my $root_wrapper = $self->root_wrapper;
    if ( !$root_wrapper ) {
        $self->twig->parsefile( $file );
    }
    else {
        open my $fh, $file or croak "Couldn't open $file:\n$!";
        binmode $fh;
        my $contents = join '', <$fh>;
        $self->parse( "<$root_wrapper>" . $contents . "</$root_wrapper>" );
    }
    return $self;
}

sub parse {
    my ( $self, $contents ) = @_;
    $self->twig->parse( $contents );
    return $self;
}

sub to_perl {
    my ( $self ) = @_;

    my $root = $self->twig->root or die "no root";

    my $data = $self->elt_to_perl( $root );

    return $data;
}

sub elt_to_perl {
    my ( $self, $elt, $opt ) = @_;
    $opt ||= {};
    $elt = $elt->first_child if $self->check_element_as_only_child( $elt );
    return $self->complex_elt_to_perl( $elt, $opt ) if $elt->is_elt;
    return $elt->text if !$elt->is_field;
    die "unknown element";
}

sub check_element_as_only_child {
    my ( $self, $elt ) = @_;

    return if !$self->element_as_only_child;
    return if !$self->element_as_only_child->( $elt );

    die "element does not have exactly one child" if $elt->children != 1;
    return 1;
}

sub complex_elt_to_perl {
    my ( $self, $elt, $opt ) = @_;
    my $data = {};
    $self->$_( $data, $opt, $elt ) for map "handle_$_", qw( tag children atts );
    return $data;
}

sub handle_tag {
    my ( $self, $data, $opt, $elt ) = @_;

    $data->{ $self->tag_key } = $elt->tag unless $opt->{no_tag_key};

    return;
}

sub handle_children {
    my ( $self, $data, $opt, $elt ) = @_;

    return if $self->try_child_as_specified_key( $data, $opt, $elt );
    return if $self->try_children_as_keys_by_tag( $data, $opt, $elt );
    return if $self->try_children_as_keys_by_att( $data, $opt, $elt );

    $self->store_children_in_key( $data, $opt, $elt );
    return;
}

sub try_child_as_specified_key {
    my ( $self, $data, $opt, $elt ) = @_;

    return if !$self->only_child_as_key;
    my $child_key = $self->only_child_as_key->( $elt );
    return if !$child_key;

    die "must have exactly one child" if $elt->children != 1;
    $data->{$child_key} = $self->elt_to_perl( $elt->children );
    return 1;
}

sub try_children_as_keys_by_tag {
    my ( $self, $data, $opt, $elt ) = @_;

    return if !$self->children_as_keys_by_tag;
    return if !$self->children_as_keys_by_tag->( $elt );

    die "tag with children as keys cannot have additional atts" if $elt->has_atts;
    for my $child ( $elt->children ) {
        my $key = $child->tag;
        die "key '$key' was already set on data element" if exists $data->{$key};
        $data->{$key} = $self->elt_to_perl( $child, { no_tag_key => 1 } );
    }

    $opt->{no_atts} = 1;

    return 1;
}

sub try_children_as_keys_by_att {
    my ( $self, $data, $opt, $elt ) = @_;

    return if !$self->children_as_keys_by_att;
    my $child_att = $self->children_as_keys_by_att->( $elt );
    return if !$child_att;

    die "tag with children as keys cannot have additional atts" if $elt->has_atts;
    for my $child ( $elt->children ) {
        my $key = $child->att( $child_att );
        die "child has no value in att '$key'" if !$key;
        die "key '$key' was already set on data element" if exists $data->{$key};
        $child->del_att( $child_att );
        $data->{$key} = $self->elt_to_perl( $child );
    }

    $opt->{no_atts} = 1;

    return 1;
}

sub store_children_in_key {
    my ( $self, $data, $opt, $elt ) = @_;

    $data->{ $self->children_key } = [];
    push @{ $data->{ $self->children_key } }, $self->elt_to_perl( $_ ) for $elt->children;

    return;
}

sub handle_atts {
    my ( $self, $data, $opt, $elt ) = @_;

    return if $opt->{no_atts};

    return if $self->try_atts_as_keys( $data, $opt, $elt );

    $self->store_atts_in_key( $data, $opt, $elt );

    return;
}

sub try_atts_as_keys {
    my ( $self, $data, $opt, $elt ) = @_;

    return if !$self->atts_as_keys;
    return if !$self->atts_as_keys->( $elt );

    my $atts = $elt->atts;

    for my $att ( keys %{$atts} ) {
        die "key '$att' was already set on data element" if exists $data->{$att};
        $data->{$att} = $atts->{$att};
    }

    return 1;
}

sub store_atts_in_key {
    my ( $self, $data, $opt, $elt ) = @_;

    $data->{ $self->atts_key } = $elt->atts;

    return;
}

1;
