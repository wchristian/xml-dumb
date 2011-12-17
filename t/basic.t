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
        my $is_root          = sub { $_[0]->tag eq 'preise' };
        my $is_domain_holder = sub { $_[0]->tag eq 'domains' };
        my $is_in_domain_holder = sub { $_[0]->parent and $is_domain_holder->( $_[0]->parent ) };

        ok my $xd = XML::Dumb->new(
            root_wrapper          => "preise",
            children_as_keys_when => [ $is_root, $is_domain_holder ],
            only_child_as_key     => { preis => $is_in_domain_holder },
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
