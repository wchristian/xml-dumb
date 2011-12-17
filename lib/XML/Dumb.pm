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

    my $perl = $self->elt_to_perl( $root );

    return $perl;
}

sub elt_to_perl {
    my ( $self, $elt ) = @_;
    return $self->complex_elt_to_perl( $elt ) if $elt->is_elt;
    return $elt->text if !$elt->is_field;
    die "unknown element";
}

sub complex_elt_to_perl {
    my ( $self, $elt, $opt ) = @_;
    my %perl;
    $perl{ $self->tag_key } = $elt->tag unless $opt->{no_tag_attr};

    my @children = $elt->children;

    my ( $child_attr ) = map { $_->( $elt ) } @{ $self->only_child_as_attr };
    my $children_as_attr = grep { $_->( $elt ) } @{ $self->children_as_attr_when };
    if ( $child_attr ) {
        die "cannot have more than one child" if @children > 1;
        $perl{$child_attr} = $self->elt_to_perl( $children[0] );
    }
    elsif ( $children_as_attr ) {
        die "tag with children as atts cannot have additional atts" if $elt->has_atts;
        $perl{ $_->tag } = $self->elt_to_perl( $_ ) for @children;
    }
    else {
        $perl{ $self->children_key } = [];
        push @{ $perl{ $self->children_key } }, $self->elt_to_perl( $_, { no_tag_attr => 1 } ) for @children;
    }

    return \%perl;
}

sub handle_children {

}

1;
