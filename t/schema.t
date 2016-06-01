#!/usr/bin/perl -w

use strict;
use Test::More 'no_plan';
use FindBin;
use lib 'lib';
use lib "$FindBin::Bin/lib";
use Data::Dumper;
use YAML;
use Test::DBIx::EAV qw/ get_test_dbh read_file /;
use DBIx::EAV;


my $dbh = get_test_dbh;
my $eav = DBIx::EAV->new( dbh => $dbh, tenant_id => 42 );



test_register_schema();
test_entity_type();

sub test_register_schema {

    my $schema = Load(read_file("$FindBin::Bin/entities.yml"));

    is $eav->has_data_type('int'), 1, 'has_data_type';

    $eav->register_schema($schema);

    # entity types
    my $artist = $dbh->selectrow_hashref('SELECT * from eav_entity_types WHERE name = "Artist"');
    my $cd = $dbh->selectrow_hashref('SELECT * from eav_entity_types WHERE name = "CD"');
    my $track = $dbh->selectrow_hashref('SELECT * from eav_entity_types WHERE name = "Track"');

    is $artist->{name}, 'Artist', 'Artist type rgistered';
    is $cd->{name}, 'CD', 'CD type rgistered';
    is $track->{name}, 'Track', 'Track type rgistered';

    # attributes
    my $name_attr = $dbh->selectrow_hashref(sprintf 'SELECT * from eav_attributes WHERE name = "name" AND entity_type_id = %d', $artist->{id});
    is $name_attr->{name}, 'name', 'name attr registered';
    is $name_attr->{data_type}, 'varchar', 'name attr data_type';

    my $description_attr = $dbh->selectrow_hashref(sprintf 'SELECT * from eav_attributes WHERE name = "description" AND entity_type_id = %d', $artist->{id});
    is $description_attr->{name}, 'description', 'description attr registered';
    is $description_attr->{data_type}, 'text', 'description attr data_type';

    isa_ok $eav->_types->{Artist}, 'HASH', 'Artist entity schema';
    isa_ok $eav->_types->{CD}, 'HASH', 'CD entity schema';
    isa_ok $eav->_types->{Track}, 'HASH', 'Track entity schema';

    # has_many
    is_deeply $dbh->selectrow_hashref('SELECT is_has_one, is_has_many, is_many_to_many, left_entity_type_id, right_entity_type_id FROM eav_relationships WHERE name = "tracks"'),
        {
            is_has_one => 0,
            is_has_many => 1,
            is_many_to_many => 0,
            left_entity_type_id => $cd->{id},
            right_entity_type_id => $track->{id},
        },
        'CD has_many Tracks';

    # many_to_many
    is_deeply $dbh->selectrow_hashref('SELECT is_has_one, is_has_many, is_many_to_many, left_entity_type_id, right_entity_type_id FROM eav_relationships WHERE name = "cds"'),
        {
            is_has_one => 0,
            is_has_many => 0,
            is_many_to_many => 1,
            left_entity_type_id => $artist->{id},
            right_entity_type_id => $cd->{id},
        },
        'Artist many_to_many CDs';
}


sub test_entity_type {

    my $artist = $eav->type('Artist');
    isa_ok $artist, 'DBIx::EAV::EntityType', 'entity';

    like $artist->id, qr/^\d$/, 'id';
    is $artist->name, 'Artist', 'name';

    is $artist->has_static_attribute('id'), 1, 'has_static_attribute()';
    is $artist->has_attribute('name'), 1, 'has_attribute()';
    is $artist->has_own_attribute('name'), 1, 'has_own_attribute()';
    is $artist->attribute('name')->{name}, 'name', 'attribute()';
    is $artist->attribute('id')->{is_static}, 1, 'attribute() <static attr>';
}
