#!/usr/bin/perl -w

use strict;
use Test::More 'no_plan';
use Test::Exception;
use FindBin;
use lib 'lib';
use lib "$FindBin::Bin/lib";
use Data::Dumper;
use YAML;
use Test::DBIx::EAV qw/ get_test_dbh read_file /;
use DBIx::EAV;


my $dbh = get_test_dbh( no_deploy => 1 );
my $eav = DBIx::EAV->new( dbh => $dbh, tenant_id => 42 );


test_create_tables();
test_register_types();
test_entity_type();

test_load_types();


sub test_create_tables {

    my $schema = $eav->schema;

    isa_ok $schema->translator, 'SQL::Translator', 'schema->translator';

    like $schema->get_ddl, qr/CREATE TABLE/, 'get_dll()';
    like $schema->get_ddl('JSON'), qr/SQL::Translator::Producer::JSON/, 'get_dll("JSON")';

    $eav->schema->deploy( add_drop_table => $eav->schema->db_driver_name eq 'mysql' );

    my $check_sqlt = SQL::Translator->new(
        parser => 'DBI',
        parser_args => {
            dbh => $dbh
        }
    );

    $check_sqlt->translate;
    ok $check_sqlt->schema->get_table($eav->schema->table_prefix.$_), "table '$_' created"
        for (qw/ entity_types entities attributes relationships entity_relationships /,
             map { "value_$_" } @{$eav->schema->data_types}
            );
}


sub test_register_types {

    my $schema = Load(read_file("$FindBin::Bin/entities.yml"));

    is $eav->schema->has_data_type('int'), 1, 'has_data_type';

    $eav->register_types($schema);

    # entity types
    my $artist = $dbh->selectrow_hashref('SELECT * from eav_entity_types WHERE name = "Artist"');
    my $cd = $dbh->selectrow_hashref('SELECT * from eav_entity_types WHERE name = "CD"');
    my $track = $dbh->selectrow_hashref('SELECT * from eav_entity_types WHERE name = "Track"');

    is $artist->{name}, 'Artist', 'Artist type rgistered';
    is $cd->{name}, 'CD', 'CD type rgistered';
    is $track->{name}, 'Track', 'Track type registered';
    is $track->{tenant_id}, $eav->schema->tenant_id, 'type tenant_id';

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

    dies_ok { $eav->type('Unknown') } 'type() dies for invalid types';
    my $artist = $eav->type('Artist');
    isa_ok $artist, 'DBIx::EAV::EntityType', 'entity';

    like $artist->id, qr/^\d$/, 'id';
    is $artist->name, 'Artist', 'name';

    is $artist->has_static_attribute('id'), 1, 'has_static_attribute()';
    is $artist->has_attribute('name'), 1, 'has_attribute()';
    is $artist->has_own_attribute('name'), 1, 'has_own_attribute()';
    is $artist->attribute('name')->{name}, 'name', 'attribute()';
    is $artist->attribute('id')->{is_static}, 1, 'attribute() <static attr>';

    ok $artist->has_relationship('cds'), 'has_relationship';
    ok $eav->type('CD')->has_relationship('artists'), 'incoming relationship installed';
}

sub test_load_types {

    $eav = DBIx::EAV->new( dbh => $dbh, tenant_id => 42 );
    test_entity_type();
}
