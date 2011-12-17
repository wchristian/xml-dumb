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
        my $is_root = sub { $_[0]->tag eq 'preise' };
        my $is_domains  = sub { $_[0] and $_[0]->tag eq 'domains' };
        my $is_vserver  = sub { $_[0] and $_[0]->tag eq 'vserver' };
        my $is_rserver  = sub { $_[0] and $_[0]->tag eq 'root-server' };
        my $is_mserver  = sub { $_[0] and $_[0]->tag eq 'managed-server' };
        my $is_interval = sub { $_[0] and $_[0]->tag eq 'interval' };
        my $is_housing  = sub { $_[0] and $_[0]->tag eq 'housing' };
        my $is_rhousing = sub { $_[0] and $_[0]->tag eq 'rackhousing' };
        my $is_webspace = sub { $_[0] and $_[0]->tag eq 'webspace' };
        my $is_in_interval = sub { $is_interval->( $_[0]->parent ) };
        my $is_in_domains  = sub { $is_domains->( $_[0]->parent ) };
        my $is_in_housing  = sub { $is_housing->( $_[0]->parent ) };
        my $is_in_webspace = sub { $_[0] and $is_webspace->( $_[0]->parent ) };
        my $is_in_vserver  = sub { $_[0] and $is_vserver->( $_[0]->parent ) };
        my $is_in_rserver  = sub { $_[0] and $is_rserver->( $_[0]->parent ) };
        my $is_in_rhousing = sub { $_[0] and $is_rhousing->( $_[0]->parent ) };
        my $is_in_mserver  = sub { $_[0] and $is_mserver->( $_[0]->parent ) };
        my $is_payment_interval_holder = sub {
                  $_[0]->tag eq 'zahlung'
              and $_[0]->parent
              and $_[0]->parent->parent
              and ($_[0]->parent->parent->tag eq 'root-server'
                or $_[0]->parent->parent->tag eq 'managed-server' );
        };
        my $is_named_payment_holder = sub {
                  $_[0]
              and $_[0]->tag eq 'zahlung'
              and $_[0]->parent
              and $_[0]->parent->parent
              and ($_[0]->parent->parent->tag eq 'vserver'
                or $_[0]->parent->parent->tag eq 'webspace' );
        };
        my $is_named_payment     = sub { $is_named_payment_holder->( $_[0]->parent ) };
        my $is_price_in_housing  = sub { $_[0]->parent and $is_in_housing->( $_[0]->parent ) };
        my $is_mserver_att       = sub { $is_mserver->( $_[0]->parent ) and !$_[0]->first_child->is_elt };
        my $is_mserver_item_att  = sub { $is_in_mserver->( $_[0]->parent ) and !$_[0]->first_child->is_elt };
        my $is_rhousing_item_att = sub { $is_in_rhousing->( $_[0]->parent ) and !$_[0]->first_child->is_elt };
        my $is_rserver_att       = sub { $is_rserver->( $_[0]->parent ) and !$_[0]->first_child->is_elt };
        my $is_rserver_item_att  = sub { $is_in_rserver->( $_[0]->parent ) and !$_[0]->first_child->is_elt };
        my $is_vserver_item_att  = sub { $is_in_vserver->( $_[0]->parent ) and !$_[0]->first_child->is_elt };
        my $is_webspace_att      = sub { $is_webspace->( $_[0]->parent ) and !$_[0]->first_child->is_elt };
        my $is_webspace_item_att = sub { $is_in_webspace->( $_[0]->parent ) and !$_[0]->first_child->is_elt };

        ok my $xd = XML::Dumb->new(
            root_wrapper            => "preise",
            children_as_keys_by_tag => [
                $is_root,        $is_domains,    $is_named_payment_holder, $is_in_housing,
                $is_mserver,     $is_interval,   $is_in_mserver,           $is_rhousing,
                $is_in_rhousing, $is_rserver,    $is_in_rserver,           $is_vserver,
                $is_webspace,    $is_in_vserver, $is_in_webspace,
            ],
            children_as_keys_by_att => { length => $is_payment_interval_holder },
            only_child_as_key       => { preis  => $is_in_domains },
            atts_as_keys            => [$is_in_domains],
            element_as_only_child   => [
                $is_named_payment,    $is_price_in_housing,  $is_in_interval, $is_mserver_att,
                $is_mserver_item_att, $is_rhousing_item_att, $is_rserver_att, $is_rserver_item_att,
                $is_vserver_item_att, $is_webspace_item_att, $is_webspace_att,
            ],
        );
        ok $xd->parsefile( "corpus/preise.xml" );

        my $perl = $xd->to_perl;

        ok_regression sub { Dumper $perl }, 'corpus/settings.dump';
    }

    {
        ok my $xd = XML::Dumb->new( children_as_keys_by_tag => [ sub { $_[0]->tag eq 'preise' } ] );
        ok $xd->parse( "<preise meep='1' />" );
        like( exception { $xd->to_perl }, qr/tag with children as keys cannot have additional atts/ );
    }
}
