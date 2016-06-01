# NAME

DBIx::EAV - Entity-Attribute-Value data modeling (aka 'open schema') over DBI

    my $eav = DBIx::EAV->new( dbh => $dbh, %constructor_params );

    # or
    my $eav = DBIx::EAV->connect( \%connect_info, \%constructor_params );

    # define the entities schema
    my %schema = (
        Artist => {
            has_many     => 'Review',
            many_to_many => 'CD',
            attributes   => [qw/ name:varchar description:text rating:int birth_date:datetime /]
        },

        CD => {
            has_many     => ['Track', 'Review'],
            attributes   => [qw/ title description:text rating:int /]
        },

        Track => {
            attributes   => [qw/ title description:text duration:int /]
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
    $eav->register_schema(\%schema);

    # insert data (and possibly related data)
    my $bob = $eav->model('Artist')->insert({
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
    my $bob = $eav->resultset('Artist')->find_one({ name => 'Bob' });

    # retrieve Bob's cds from CD collection
    my @cds = $eav->resultset('CD')->find({ artist => $bob })->all; # which is the same as: $bob->get('cds')->all

    # or traverse the cds using the cursor
    my $cds = $eav->resultset('CD')->find({ artist => $bob });

    while (my $cd = $cds->next) {
        print $cd->get('title');
    }

    # delete all cds
    $eav->resultset('CD')->delete;

    # delete worst cds
    $eav->resultset('CD')->delete({ rating => { '<' => 5 } });

# DESCRIPTION

An implementation of Entity-Attribute-Value data modeling with support for
entity relationships and multi-tenancy.

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
number of possible attributes likes tests results and diagnostics are huge and
just a few of those attributes are acctualy filled (non-NULL).

## When you dont't know your schema in advance

E-commerce solutions use EAV modeling to allow the definition of any kind of product
and still be able to do filtering/sorting of results based of product attributes.
For example, the entity 'HardDrive' would have atrributes 'capacity' and 'rpm',
while entity 'Monitor' would have attributes 'resolution' and 'contrast\_ratio'.

## When you need frequent changes to your schema

Many SaaS platforms use EAV modeling to offer database services to its custormers,
without exposing the physical database system.

# CONCEPTS

## PHYSICAL SCHEMA

## EAV SCHEMA

## ENTITY TYPE

## ENTITY

## COLLECTION

## CURSOR

# METHODS

## new

## register\_schema

> Register entity types specified in \\%schema, where each key is the name of the
> entity and the value is a hashref describing its attributes and relationships.
> Described in detail in ["ENTITY DEFINITION"](#entity-definition).

## resultset

- Arguments: $type\_name
- Return value: [$rs](https://metacpan.org/pod/DBIx::EAV::ResultSet)

Returns a new [resultset](https://metacpan.org/pod/DBIx::EAV::ResultSet) instance for type `$type`.

    my $rs = $eav->resultset('Artist');

## type

    my $types = $eav->type('Artist');

Returns the [DBIx::EAV::EntityType](https://metacpan.org/pod/DBIx::EAV::EntityType) instance for type $name. Dies if type is not installed.

## has\_type

Returns true if type $name is installed.

## schema

Returns the [DBIx::EAV::Schema](https://metacpan.org/pod/DBIx::EAV::Schema) instance representing the physical database schema.

## table

# ENTITY DEFINITION

An entity definition is in the form of EntityName => \\%definition,
where the possible keys for %definition are:

- attributes
- has\_one
- has\_many
- many\_to\_many

# CASCASDE DELETE

# QUERY OPTIONS

# LICENSE

Copyright (C) Carlos Fernando Avila Gratz.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Carlos Fernando Avila Gratz &lt;cafe@kreato.com.br>

# POD ERRORS

Hey! **The above document had some coding errors, which are explained below:**

- Around line 323:

    Unknown directive: =head

- Around line 465:

    &#x3d;over should be: '=over' or '=over positive\_number'

- Around line 475:

    You forgot a '=back' before '=head2'
