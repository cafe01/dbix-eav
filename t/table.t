#!/usr/bin/perl -w

use strict;
use Test::More 'no_plan';
use FindBin;
use lib 'lib';
use lib "$FindBin::Bin/lib";
use Data::Dumper;
use Test::DBIx::EAV qw/ get_test_dbh /;

BEGIN { use_ok 'DBIx::EAV::Table' }

my $dbh = get_test_dbh;

my $table = DBIx::EAV::Table->new(
    dbh => $dbh,
    tenant_id => 42,
    name => 'eav_entity_types',
    columns => [qw/ id tenant_id name /]
);



test_insert();
test_select();
test_select_one();
test_update();
test_delete();


sub test_insert {

    diag 'testing insert()';

    my $res = $table->insert({ name => 'Foo' });

    is $res, 1, 'insert return value';

    is_deeply $dbh->selectrow_hashref('SELECT * from eav_entity_types WHERE id = '.$res),
              { id => $res, name => 'Foo', tenant_id => $table->tenant_id },
              'inserted data is there';

    is $table->insert({ name => 'Bar' }), $res + 1, 'insert returns last inserted';
}

sub test_select {

    diag 'testing select()';

    my $res = $table->select({ name => 'Foo' });
    isa_ok $res, 'DBI::st', 'returns statement handle';
    is_deeply $res->fetchrow_hashref, { id => 1, name => 'Foo', tenant_id => $table->tenant_id }, 'selected data';

}

sub test_select_one {

    diag 'testing select_one()';

    my $res = $table->select_one({ name => 'Foo' });
    isa_ok $res, 'HASH', 'returns hashref';
    is_deeply $res, { id => 1, name => 'Foo', tenant_id => $table->tenant_id }, 'found data';

}

sub test_update {

    diag 'testing update()';

    my $res = $table->update({ name => 'FooBar' }, { id => 1});

    is $res, 1, 'update() rv';
    is_deeply $dbh->selectrow_hashref('SELECT * from eav_entity_types WHERE id = 1'),
              { id => 1, name => 'FooBar', tenant_id => $table->tenant_id },
              'updated   data is there';
}

sub test_delete {

    diag 'testing delete()';

    my $res = $table->delete({ id => 1});

    is $res, 1, 'delete() rv';

    is $dbh->selectrow_hashref('SELECT * from eav_entity_types WHERE id = 1'), undef, 'deleted row is gone';
}
