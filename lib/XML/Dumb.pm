use strictures;

package XML::Dumb;

use Carp 'croak';
use XML::Twig;
use Moo;

has $_ => ( is => 'ro', lazy => 1, builder => "_build_$_" ) for qw( twig );
has $_ => ( is => 'ro' ) for qw( root_wrapper );
has children_key          => ( is => 'ro', default => sub { 'children' } );
has tag_key               => ( is => 'ro', default => sub { 'tag' } );
has attrs_key             => ( is => 'ro', default => sub { 'attrs' } );
has children_as_attr_when => ( is => 'ro', default => sub { [] } );
has only_child_as_attr    => ( is => 'ro', default => sub { [] } );

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
    my ( $self, $elt ) = @_;
    return $self->complex_elt_to_perl( $elt ) if $elt->is_elt;
    return $elt->text if !$elt->is_field;
    die "unknown element";
}

sub complex_elt_to_perl {
    my ( $self, $elt, $opt ) = @_;
    my $data = {};
    $self->$_( $data, $opt, $elt ) for map "handle_$_", qw( tag children attrs );
    return $data;
}

sub handle_tag {
    my ( $self, $data, $opt, $elt ) = @_;

    $data->{ $self->tag_key } = $elt->tag unless $opt->{no_tag_attr};

    return;
}

sub handle_children {
    my ( $self, $data, $opt, $elt ) = @_;

    my @children = $elt->children;

    return if $self->try_child_as_specified_attr( $data, $opt, $elt, \@children );
    return if $self->try_children_as_attrs_by_tag( $data, $opt, $elt, \@children );

    $self->store_children_in_attr( $data, $opt, $elt, \@children );
    return;
}

sub try_child_as_specified_attr {
    my ( $self, $data, $opt, $elt, $children ) = @_;

    my ( $child_attr ) = map { $_->( $elt ) } @{ $self->only_child_as_attr };
    return if !$child_attr;

    die "cannot have more than one child" if @{$children} > 1;
    $data->{$child_attr} = $self->elt_to_perl( $children->[0] );
    return 1;
}

sub try_children_as_attrs_by_tag {
    my ( $self, $data, $opt, $elt, $children ) = @_;

    my $children_as_attr = grep { $_->( $elt ) } @{ $self->children_as_attr_when };
    return if !$children_as_attr;

    die "tag with children as atts cannot have additional atts" if $elt->has_atts;
    $data->{ $_->tag } = $self->elt_to_perl( $_ ) for @{$children};
    return 1;
}

sub store_children_in_attr {
    my ( $self, $data, $opt, $elt, $children ) = @_;

    $data->{ $self->children_key } = [];
    push @{ $data->{ $self->children_key } }, $self->elt_to_perl( $_, { no_tag_attr => 1 } ) for @{$children};

    return;
}

sub handle_attrs {
    my ( $self, $data, $opt, $elt ) = @_;

    return;
}

1;
