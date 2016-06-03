#!/usr/bin/perl -w

use strict;
use Test::More 'no_plan';
use FindBin;
use lib 'lib';
use lib "$FindBin::Bin/lib";
use Data::Dumper;
use YAML;
use Test::Exception;
use Test::DBIx::EAV qw/ get_test_dbh read_file /;
use DBIx::EAV;


my $eav = DBIx::EAV->new( dbh => get_test_dbh, tenant_id => 42 );
$eav->schema->deploy( add_drop_table => $eav->db_driver_name eq 'mysql');
$eav->register_types(Load(read_file("$FindBin::Bin/entities.yml")));


test_has_many();
test_many_to_many();
test_has_one();



sub test_has_many {

    # insert related data
    my $cd1 = $eav->resultset('CD')->insert({
        title => 'CD 01',
        tracks => [
            { title => 'Track1', duration => 60 },
            { title => 'Track2', duration => 90 },
            { title => 'Track3', duration => 120 }
        ]
    });

    # rels installed
    is $eav->type('CD')->relationship('tracks')->{name}, 'tracks', 'tracks relationship installed on CD';
    is $eav->type('Track')->relationship('cd')->{name}, 'cd', 'cd relationship installed on Track';

    # cd->tracks
    is_deeply [map { $_->get('title') } $cd1->get('tracks')->all], [qw/ Track1 Track2 Track3 /], 'cd->tracks';

    is_deeply [map { $_->get('title') } $cd1->get('tracks', { duration => { '>' => 60 }})->all],
              [qw/ Track2 Track3 /], 'cd->tracks + query';

    is_deeply [map { $_->get('title') } $cd1->get('tracks', { duration => { '>' => 60 }}, { order_by => { -desc => 'duration' }})->all],
              [qw/ Track3 Track2 /], 'cd->tracks + query options';

    # move track2 to cd2
    diag "moving track2 to cd2";
    my $track2 = $eav->resultset('Track')->find({ title => 'Track2' });
    my $cd2 = $eav->resultset('CD')->insert({ title => 'CD2' });

    $cd2->add_related('tracks', [$track2, { title => 'Track4' }, { title => 'Track5' }]);

    is_deeply [map { $_->get('title') } $cd1->get('tracks')->all], [qw/ Track1 Track3 /], 'cd1->tracks';
    is_deeply [map { $_->get('title') } $cd2->get('tracks')->all], [qw/ Track2 Track4 Track5 /], 'cd2->tracks';

    # track->cd
    is $track2->get('cd')->id, $cd2->id, 'track2->cd';

    # remove related
    my $track4 = $eav->resultset('Track')->find({ title => 'Track4' });

    $cd2->remove_related('tracks', $track4);
    is_deeply [map { $_->get('title') } $cd2->get('tracks')->all], [qw/ Track2 Track5 /], 'track4 removed from cd2';

    # delete track2
    $track2->delete;
    is_deeply [map { $_->get('title') } $cd2->get('tracks')->all], [qw/ Track5 /], 'track2 deleted';

    # deleting  cd1 deletes its tracks
    $cd1->delete;
    is $eav->resultset('Track')->find({ title => 'Track1' }), undef, 'deleting cd1 deletes its tracks';

    $eav->resultset("CD")->delete;
    $eav->resultset("Track")->delete;
}


sub test_many_to_many {

    my $artists = $eav->resultset('Artist');
    my $cds = $eav->resultset('CD');

    my $a1 = $artists->insert({ name => 'Artist1', cds => [{ title => 'CD1'}, { title => 'CD2'}, { title => 'CD3'}] });
    my $a2 = $artists->insert({ name => 'Artist2', cds => [{ title => 'CD4'}, { title => 'CD5'}, { title => 'CD6'}] });

    is_deeply [map { $_->get('title') } $a1->get('cds')->all], [qw/ CD1 CD2 CD3 /], 'artist1->cds';

    # add a2 cds to a1
    $a1->add_related('cds', [$a2->get('cds')->all]);

    is_deeply [map { $_->get('title') } $a1->get('cds')->all], [qw/ CD1 CD2 CD3 CD4 CD5 CD6 /], 'added a2 cds to a1';
    is_deeply [map { $_->get('title') } $a2->get('cds')->all], [qw/ CD4 CD5 CD6 /], 'a2 cds still there';

    # cd->artists
    my $cd4 = $cds->find({ title => 'CD4' });
    is_deeply [map { $_->get('name') } $cd4->get('artists')->all], [qw/ Artist1 Artist2 /], 'cd->artists';

    # remove CD4 from a2
    $a2->remove_related('cds', $cd4);

    is_deeply [map { $_->get('title') } $a2->get('cds')->all], [qw/ CD5 CD6 /], 'removed CD4 from a2';

    # delete a2
    $a2->delete;
    is_deeply [map { $_->get('title') } $a1->get('cds')->all], [qw/ CD1 CD2 CD3 CD4 CD5 CD6 /], 'deleting a2 doesnt delete tracks';

    $artists->delete_all;
    $cds->delete_all;
}


sub test_has_one {

    my $track = $eav->resultset('Track')->insert({ title => 'Some Track', lyric => { content => 'loren ipsum' }});

    is $track->get('lyric')->get('content'), 'loren ipsum', 'track->lyric';
    is $track->get('lyric')->get('track')->id, $track->id, 'lyric->track';

    dies_ok { $track->add_related('lyric', {} ) } 'add_related forbiden for has_one';
    dies_ok { $track->remove_related('lyric', {} ) } 'remove_related forbiden for has_one';
}
