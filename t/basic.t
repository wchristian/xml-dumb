use strictures;

use Test::More;
use Test::InDistDir;
use Test::Fatal 'exception';
use Data::Dumper 'Dumper';
use Test::Regression;

use XML::Dumb;

run();
done_testing;

sub run {
    $ENV{TEST_REGRESSION_GEN} = 0;
    $Data::Dumper::Sortkeys   = 1;
    $Data::Dumper::Indent     = 1;

    {
        ok my $xd = XML::Dumb->new;
        like( exception { $xd->parsefile( "corpus/preise.xml" ) }, qr/junk after document element/ );
    }

    {
        ok my $xd = XML::Dumb->new( root_wrapper => "preise" );
        ok $xd->parsefile( "corpus/preise.xml" );

        my $perl = $xd->to_perl;

        ok_regression sub { Dumper $perl }, 'corpus/basic.dump';
    }

    {
        ok my $xd = XML::Dumb->new(
            root_wrapper          => "preise",
            children_as_keys_when => [ sub { $_[0]->tag eq 'preise' or $_[0]->tag eq 'domains' } ],
            only_child_as_key     => [ sub { return 'preis' if $_[0]->parent and $_[0]->parent->tag eq 'domains' } ],
        );
        ok $xd->parsefile( "corpus/preise.xml" );

        my $perl = $xd->to_perl;

        ok_regression sub { Dumper $perl }, 'corpus/settings.dump';
    }

    {
        ok my $xd = XML::Dumb->new( children_as_keys_when => [ sub { $_[0]->tag eq 'preise' } ] );
        ok $xd->parse( "<preise meep='1' />" );
        like( exception { $xd->to_perl }, qr/tag with children as keys cannot have additional atts/ );
    }
}