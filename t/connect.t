#!/usr/bin/perl -w

use strict;
use Test::More;
use lib "lib";
use DBIx::EAV;


my $eav = DBIx::EAV->connect('dbi:SQLite:database=:memory:', undef, undef, { RaiseError => 1 }, { tenant_id => 42 });

isa_ok $eav, 'DBIx::EAV', 'connect() return';
isa_ok $eav->dbh, 'DBI::db', 'eav->dbh';
is $eav->dbh->{RaiseError}, 1, 'DBI attrs';

done_testing;
