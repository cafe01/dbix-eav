[![Build Status](https://travis-ci.org/cafe01/dbix-eav.svg?branch=master)](https://travis-ci.org/cafe01/dbix-eav)
# NAME

DBIx::EAV - Entity-Attribute-Value data modeling (aka 'open schema') for Perl

# SYNOPSIS

    my $eav = DBIx::EAV->new( dbh => $dbh, %constructor_params );

    # or
    my $eav = DBIx::EAV->connect( $dbi_dsn, $dbi_user, $dbi_pass, $dbi_attrs, \%constructor_params );

    # define the entities schema
    my %schema = (

        Artist => {
            has_many     => 'Review',
            many_to_many => 'CD',
            attributes   => [qw/ name:varchar description:text rating:int birth_date:datetime /]
        },

        CD => {
            has_many     => ['Track', 'Review'],
            has_one      => ['CoverImage'],
            attributes   => [qw/ title description:text rating:int /]
        },

        Track => {
            attributes   => [qw/ title description:text duration:int /]
        },

        CoverImage => {
            attributes   => [qw/ url /]
        },

        Review => {
            attributes => [qw/ content:text likes:int dislikes:int /]
        },

        User => {
            has_many => 'Review',
            attributes => [qw/ name email /]
        }
    );

    # register schema (can be called multiple times)
    $eav->register_types(\%schema);

    # insert data (and possibly related data)
    my $bob = $eav->resultset('Artist')->insert({
            name => 'Robert',
            description => '...',
            cds => [
                { title => 'CD1', rating => 5 },
                { title => 'CD2', rating => 6 },
                { title => 'CD3', rating => 8 },
                { title => 'CD4', rating => 9 },
            ]
     });

    # get attributes
    $bob->get('name'); # Robert

    # update name
    $bob->update({ name => 'Bob' });

    # add more cds
    $bob->add_related('cds', { title => 'CD5' });

    # get Bob's cds via auto-generated 'cds' relationship
    my @cds = $bob->get('cds')->all;
    my @best_bob_cds = $bob->get('cds', { rating => { '>' => 7 } })->all;


    # ResultSets ...


    # retrieve Bob from database
    my $bob = $eav->resultset('Artist')->find({ name => 'Bob' });

    # retrieve Bob's cds from CD collection
    my @cds = $eav->resultset('CD')->search({ artist => $bob })->all; # which is the same as: $bob->get('cds')->all

    # or traverse the cds using the cursor
    my $cds_rs = $eav->resultset('CD')->search({ artist => $bob });

    while (my $cd = $cds_rs->next) {
        print $cd->get('title');
    }

    # delete all cds
    $eav->resultset('CD')->delete;

    # delete worst cds
    $eav->resultset('CD')->delete({ rating => { '<' => 5 } });

# DESCRIPTION

An implementation of Entity-Attribute-Value data modeling with support for
entity relationships and multi-tenancy.

# ALPHA STAGE

This project is in its infancy, and the main purpose of this stage is to let
other developers try it, and help identify any major design flaw before we can
stabilize the API. One exception is the ResultSet whose API (and docs :\]) I've
borrowed from [DBIx::Class](https://metacpan.org/pod/DBIx::Class), so its (API is) already stable.

# WHAT'S EAV?

EAV is a data model where instead of representing each entity using a physical
table with columns representing its attributes, everything is stored as rows of
the eav tables. Each entity is stored as a row of the 'entities' table, and each
of its attributes values are stored as a row of one of the values table. There is
one value table for each data type.

For a better explanation of what an Entity-Attribute-Value data model is, check Wikipedia.
The specific tables used by this implementation are described in [DBIx::EAV::Schema](https://metacpan.org/pod/DBIx::EAV::Schema).

# EAV USE CASES

## When the number of possible attributes is huge

EAV modeling has been used by health and clinical software by decades because the
number of possible attributes like tests results and diagnostics are huge and
just a few of those attributes are acctualy filled (non-NULL).

## When you dont't know your schema in advance

E-commerce solutions use EAV modeling to allow the definition of any kind of product
and still be able to do filtering/sorting of results based of product attributes.
For example, the entity 'HardDrive' would have atrributes 'capacity' and 'rpm',
while entity 'Monitor' would have attributes 'resolution' and 'contrast\_ratio'.

## To abstract the physical database layer

Many SaaS platforms use EAV modeling to offer database services to its custormers,
without exposing the physical database system.

## When you need frequent changes to your schema

An open-schema data model can be useful for app prototyping.

# DBIx::EAV CONCEPTS

## EntityType

An [EntityType](https://metacpan.org/pod/DBIx::EAV::EntityType) is the blueprint of an entity. Like a
Class in OOP. Each type has  a unique name, one or more attributes and zero or
more relationships. See [DBIx::EAV::EntityType](https://metacpan.org/pod/DBIx::EAV::EntityType).

## Entity

An actual entity record (of some type) that has its own id and attribute values.
See [DBIx::EAV::Entity](https://metacpan.org/pod/DBIx::EAV::Entity).

## Attribute

Attributes are analogous to columns in traditional database modeling. Its the
actual named properties that describes an entity type. Every attribute has a
unique name and a data type. Unlike traditional table columns, adding/removing
attributes to an existing entity type is very easy and cheap.

## Value

The actual attribute data stored in one of the value tables. There is one value
table for each data type.
See ["data\_types"](#data_types), [DBIx::EAV::Schema](https://metacpan.org/pod/DBIx::EAV::Schema).

## Physical Schema

This is the actual database tables used by the EAV system. Its represented by
[DBIx::EAV::Schema](https://metacpan.org/pod/DBIx::EAV::Schema).

## EAV Schema

Its the total set of Entity Types registered on the system, which form the
actual application business model.
See ["register\_schema"](#register_types).

## ResultSet

Concept borrowed from [DBIx::Class](https://metacpan.org/pod/DBIx::Class), a ResultSet represents a query used for
fetching a set of entities of a type, as well as other CRUD operations on
multiple entities.

## Cursor

A Cursor is used internally by the ResultSet to prepare, execute and traverse
through SELECT queries.

# CONSTRUCTORS

## new

## connect

- Arguments: $dsn, $user, $pass, $attrs, $constructor\_params
- Return Value: $eav

Connects to the database via `DBI->connect($dsn, $user, $pass, $attrs)`
then returns a new instance via ["new"](#new).

# METHODS

## register\_schema

- Arguments: \\%schema
- Return value: none

Register entity types specified in \\%schema, where each key is the name of the
entity and the value is a hashref describing its attributes and relationships.
Described in detail in ["ENTITY DEFINITION" in DBIx::EAV::EntityType](https://metacpan.org/pod/DBIx::EAV::EntityType#ENTITY-DEFINITION).

## resultset

- Arguments: $name
- Return value: [$rs](https://metacpan.org/pod/DBIx::EAV::ResultSet)

Returns a new [resultset](https://metacpan.org/pod/DBIx::EAV::ResultSet) instance for
[type](https://metacpan.org/pod/DBIx::EAV::EntityType) `$name`.

    my $rs = $eav->resultset('Artist');

## type

- Arguments: $name

Returns the [DBIx::EAV::EntityType](https://metacpan.org/pod/DBIx::EAV::EntityType) instance for type `$name`. Dies if type
is not installed.

    my $types = $eav->type('Artist');

## has\_type

- Arguments: $name

Returns true if [entity type](https://metacpan.org/pod/DBIx::EAV::EntityType) `$name` is installed.

## schema

Returns the [DBIx::EAV::Schema](https://metacpan.org/pod/DBIx::EAV::Schema) instance representing the physical database schema.

## table

Shortcut for `->schema->table`.

## data\_types

Returns an arrayref of data types known to the system. See ["new"](#new).

## has\_data\_type

- Arguments: $name

Returns true if the data type `$name` exists. See ["data\_types"](#data_types).

## db\_driver\_name

Shortcut for `$self->dbh->{Driver}{Name}`.

## dbh\_do

- Arguments: $stmt, \\@bind?
- Return Values: ($rv, $sth)

    Prepares `$stmt` and executes with the optional `\@bind` values. Returns the
    return value from execute `$rv` and the actual statement handle `$sth` object.

    Set environment variable `DBIX_EAV_TRACE` to 1 to get statements printed to
    `STDERR`.

# CASCADE DELETE

Since a single [entity](https://metacpan.org/pod/DBIx::EAV::Entity)'s data is spread over several value
tables, we can't just delete the entity in a single SQL `DELETE` command.
We must first send a `DELETE` for each of those value tables, and one more for
the [entity\_relationships](https://metacpan.org/pod/DBIx::EAV::Schema#entity_relationships) table. If an
entity has attributes of 4 data types, and has any relationship defined, a total
of 6 (six!!) `DELETE` commands will be needed to delete a single entity. Four
to the value tables, one for the entity\_relationships and one for the actual
entities table).

Those extra `DELETE` commands can be avoided by using database-level
`ON DELETE CASCADE` for the references from the **values** and
**entity\_relationships** tables to the **entities** table.

If those contraints are in place, set [database\_cascade\_delete](https://metacpan.org/pod/new) to `1` and
those extra `DELETE` commands will not be sent.

# LICENSE

Copyright (C) Carlos Fernando Avila Gratz.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Carlos Fernando Avila Gratz &lt;cafe@kreato.com.br>
