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
        my %x_cache;
        my $cpath = sub {
            my ( $elt ) = @_;
            $x_cache{$elt} ||= $elt->xpath;
            return $x_cache{$elt};
        };

        my $is_in_domains = sub { $cpath->( $_[0] ) =~ m@^/preise/domains/[\w\.]+$@ };

        my $repeat_group = "managed-server|rackhousing|root-server|vserver|webspace";

        ok my $xd = XML::Dumb->new(
            root_wrapper            => "preise",
            children_as_keys_by_tag => [
                sub { $_[0]->tag eq "preise" },
                sub { $cpath->( $_[0] ) =~ m@^/preise/(domains|$repeat_group)$@ },
                sub { $cpath->( $_[0] ) =~ m@^/preise/(housing|$repeat_group)/\w+$@ },
                sub { $cpath->( $_[0] ) =~ m@^/preise/(vserver|webspace)/\w+/zahlung$@ },
                sub { $cpath->( $_[0] ) =~ m@^/preise/[\w+\-]+/\w+/zahlung/interval\[\d\]$@ },
            ],
            children_as_keys_by_att => {
                length => sub { $cpath->( $_[0] ) =~ m@^/preise/(root|managed)-server/\w+/zahlung$@ }
            },
            only_child_as_key     => { preis => $is_in_domains },
            atts_as_keys          => [$is_in_domains],
            element_as_only_child => [
                sub {
                    my ( $elt ) = @_;
                    return if !$_[0]->first_child or $_[0]->first_child->is_elt;

                    my $xpath = $cpath->( $elt );
                    return 1 if $xpath =~ m@^/preise/(managed-server|root-server|webspace)/\w+$@;
                    return 1 if $xpath =~ m@^/preise/(housing|$repeat_group)/\w+/\w+$@;
                    return 1 if $xpath =~ m@^/preise/(vserver|webspace)/\w+/zahlung/\w+$@;
                    return 1 if $xpath =~ m@^/preise/(managed|root)-server/\w+/zahlung/interval\[\d\]/\w+$@;
                    return;
                },
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
