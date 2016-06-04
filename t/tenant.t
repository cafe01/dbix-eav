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
my $eav_schema = Load(read_file("$FindBin::Bin/entities.yml"));


# tenant 1
my $eav = DBIx::EAV->new( dbh => $dbh, tenant_id => 1 );
$eav->schema->deploy( add_drop_table => $eav->schema->db_driver_name eq 'mysql');
$eav->register_types($eav_schema);

my $t1artist = $eav->type('Artist');

# tenant 2
diag "tenant 2";
$eav = DBIx::EAV->new( dbh => $dbh, tenant_id => 2 );
$eav->register_types($eav_schema);

isnt $t1artist->id, $eav->type('Artist')->id, 'each tenant gets its own types';


# no tenant
$dbh = get_test_dbh();
$eav = DBIx::EAV->new( dbh => $dbh );
$eav->schema->deploy( add_drop_table => $eav->schema->db_driver_name eq 'mysql');
$eav->register_types($eav_schema);


my $artist = $eav->type('Artist');
ok $eav->type('Artist'), 'no tenant - type registered';

is_deeply $dbh->selectrow_hashref('SELECT * from eav_entity_types WHERE id = '.$artist->id),
    { id => $artist->id, name => 'Artist' }, 'no tenant - type row';
