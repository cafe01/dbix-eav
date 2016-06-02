package DBIx::EAV;

use Moo;
use strictures 2;
use DBI;
use DateTime;
use Lingua::EN::Inflect ();
use Data::Dumper;
use DBIx::EAV::EntityType;
use DBIx::EAV::Entity;
use DBIx::EAV::ResultSet;
use DBIx::EAV::Schema;
use constant {
    SQL_DEBUG => $ENV{DBIX_EAV_TRACE}
};
use Carp qw/croak confess/;
use Scalar::Util 'blessed';

our $VERSION = "0.01";

# required
has 'dbh', is => 'ro', required => 1;

# optional
has 'database_cascade_delete', is => 'ro', default => 0;
has 'table_prefix', is => 'ro', default => 'eav_';
has 'tenant_id', is => 'ro';
has 'data_types', is => 'ro', default => sub { [qw/ int decimal varchar text datetime boolean /] };
has 'schema', is => 'rw';
has 'default_data_type', is => 'ro', default => 'varchar';

# internal
has '_types', is => 'ro', default => sub { {} };
has '_types_by_id', is => 'ro', default => sub { {} };


sub BUILD {
    my $self = shift;

    my %schema_params = (
        dbh          => $self->dbh,
        tenant_id    => $self->tenant_id,
        table_prefix => $self->table_prefix
    );

    # must be one of: (DBIx::EAV::)Schema instance, Schema subclass name, or Schema config
    if (defined $self->schema) {

        my $schema = $self->schema;

        if (blessed $schema) {
            die sprintf("invalid schema: %s is not a DBIx::EAV::Schema or subclass.", ref $schema)
                unless $schema->isa('DBIx::EAV::Schema');

            $schema->tenant_id($self->tenant_id);
        }
        else {

            if (ref $schema eq 'HASH') {
                $self->schema(DBIx::EAV::Schema->new( %schema_params ))
            }
            elsif (ref $schema eq '') {
                require $schema;
                $self->schema($schema->new( %schema_params ));
            }
            else {
                die "Invalid schema. Must be one of: (DBIx::EAV::)Schema instance, Schema subclass name, or Schema config";
            }
        }
    }
    else {

        my $schema = DBIx::EAV::Schema->new(
            %schema_params,
            tables => {

                entities =>
                    [qw/ id tenant_id entity_type_id created_at updated_at is_deleted is_active is_published /],

                entity_types =>
                    [qw/ id tenant_id name /],

                attributes =>
                    [qw/ id tenant_id entity_type_id name data_type /],

                relationships =>
                    [qw/ id tenant_id name left_entity_type_id right_entity_type_id is_has_one is_has_many is_many_to_many /],

                entity_relationships =>
                    [qw/ relationship_id left_entity_id right_entity_id /],

                type_hierarchy =>
                    [qw/ parent_type_id child_type_id /],

                map {
                    ("value_$_" => [qw/ entity_id attribute_id value /])
                } @{ $self->data_types }
            }
        );

        $self->schema($schema);
    }
}

sub db_driver_name {
    shift->dbh->{Driver}{Name};
}



sub dbh_do {
    my ($self, $stmt, $bind) = @_;

    if (SQL_DEBUG) {
        my $i = 0;
        printf STDERR "$stmt: %s\n",
            join('  ', map { $i++.'='.$_ } @{ $bind || [] });
    }

    my $sth = $self->dbh->prepare($stmt);
    my $rv = $sth->execute(ref $bind eq 'ARRAY' ? @$bind : ());
    die $sth->errstr unless defined $rv;

    return ($rv, $sth);
}

sub has_data_type {
    my ($self, $name) = @_;
    foreach (@{$self->data_types}) {
        return 1 if $_ eq $name;
    }
    0;
}

sub table {
    my ($self, $name) = @_;
    $self->schema->table($name);
}

sub has_type {
    my ($self, $name) = @_;
    exists $self->_types->{$name};
}


sub type {
    my ($self, $name) = @_;
    confess "Entity '$name' does not exist."
        unless exists $self->_types->{$name};

    $self->_types->{$name};
}

sub type_by_id {
    my ($self, $id) = @_;
    confess "Can't find type by id '$id'"
        unless exists $self->_types_by_id->{$id};

    $self->_types_by_id->{$id};
}


sub resultset {
    my ($self, $name) = @_;

    DBIx::EAV::ResultSet->new({
        eav  => $self,
        type => $self->type($name),
    });
}


sub register_schema {
    my ($self, $schema) = @_;
    my %skip;

    # register only not-installed entities to
    # allow multiple calls to this method
    my @new_types = grep { not exists $self->_types->{$_} } keys %$schema;

    # create or update each entity type on database
    foreach my $name (@new_types) {
        next if exists $self->_types->{$name};
        $self->_register_entity($name, $schema->{$name}, $schema);
    }

    # register relationships
    foreach my $name (@new_types) {

        my $spec = $schema->{$name};
        my $entity_type = $self->type($name);

        foreach my $reltype (qw/ has_one has_many many_to_many /) {

            next unless defined $spec->{$reltype};

            $spec->{$reltype} ||= [];
            $spec->{$reltype} = [$spec->{$reltype}]
                unless ref $spec->{$reltype} eq 'ARRAY';

            foreach my $rel (@{$spec->{$reltype}}) {
                $entity_type->register_relationship($reltype, $rel);
            }
        }
    }
}


sub _register_entity {
    my ($self, $name, $spec, $schema) = @_;

    # parent type first
    my $parent_type;
    if ($spec->{extends}) {

        unless ($parent_type = $self->_types->{$spec->{extends}}) {

            die "Unknown type '$spec->{extends}' specified in 'extents' option for type '$name'."
                unless exists $schema->{$spec->{extends}};

            $parent_type = $self->_register_entity($spec->{extends}, $schema->{$spec->{extends}}, $schema);
        }
    }

    # find or create entity type
    my $types_table = $self->table('entity_types');
    my $hierarchy_table = $self->table('type_hierarchy');
    my $type = $types_table->select_one({ name => $name });

    if (defined $type) {

        # change parent
    }
    else {

        # TODO implement rename
        # if ($spec->{rename_from}) { ... }

        my $id = $types_table->insert({ name => $name });
        $type = $types_table->select_one({ id => $id });
        die "Error inserting entity type '$name'!" unless $type;

        if ($parent_type) {
            $hierarchy_table->insert({
                parent_type_id => $parent_type->{id},
                child_type_id  => $type->{id}
            });

            $type->{parent} = $parent_type;
        }
    }

    # update or create attributes
    my $attributes = $self->table('attributes');
    my %static_attributes = map { $_ => {name => $_, is_static => 1} } @{$self->table('entities')->columns};
    $type->{static_attributes} = \%static_attributes;
    $type->{attributes} = {};

    my %inherited_attributes = $parent_type ? map { $_->{name} => $_ } $parent_type->attributes( no_static => 1 )
                                            : ();

    foreach my $attr_spec (@{$spec->{attributes}}) {

        # expand string to name/type
        unless (ref $attr_spec) {
            my ($name, $type) = split ':', $attr_spec;
            $attr_spec = {
                name => $name,
                type => $type || $self->default_data_type
            };
        }

        die sprintf("Error registering attribute '%s' for  entity '%s'. Can't use names of static attributes (real table columns).", $attr_spec->{name}, $type->{name})
            if exists $static_attributes{$attr_spec->{name}};

        printf STDERR "[warn] entity '%s' is overriding inherited attribute '%s'", $name, $attr_spec->{name}
            if $inherited_attributes{$attr_spec->{name}};

        my $attr = $attributes->select_one({
            entity_type_id => $type->{id},
            name => $attr_spec->{name}
        });

        if (defined $attr) {
            # update
        }
        else {
            delete $attr_spec->{id}; # safety

            my %data = %$attr_spec;

            $data{entity_type_id} = $type->{id};
            $data{data_type} = delete($data{type}) || $self->default_data_type;

            die sprintf("Attribute '%s' has unknown data type '%s'.", $data{name}, $data{data_type})
                unless $self->has_data_type($data{data_type});

            $attributes->insert(\%data);
            $attr = $attributes->select_one(\%data);
            die "Error inserting attribute '$attr_spec->{name}'!" unless $attr;
        }

        $type->{attributes}{$attr->{name}} = $attr;
    }

    $self->_types->{$name} =
        $self->_types_by_id->{$type->{id}} = DBIx::EAV::EntityType->new(%$type, core => $self);
}



1;

__END__

=encoding utf-8

=head1 NAME

DBIx::EAV - Entity-Attribute-Value data modeling (aka 'open schema') over DBI

=head1 SYNOPSIS

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


=head1 DESCRIPTION

An implementation of Entity-Attribute-Value data modeling with support for
entity relationships and multi-tenancy.

=head1 ALPHA STAGE

This project is in its infancy, and the main purpose of this stage is to let
other developers try it, and help identify any major design flaw before we can
stabilize the API. One exception is the ResultSet whose API (and docs :]) I've
borrowed from L<DBIx::Class>, so its (API is) already stable.

=head1 WHAT'S EAV?

EAV is a data model where instead of representing each entity using a physical
table with columns representing its attributes, everything is stored as rows of
the eav tables. Each entity is stored as a row of the 'entities' table, and each
of its attributes values are stored as a row of one of the values table. There is
one value table for each data type.

For a better explanation of what an Entity-Attribute-Value data model is, check Wikipedia.
The specific tables used by this implementation are described in L<DBIx::EAV::Schema>.

=head1 EAV USE CASES

=head2 When the number of possible attributes is huge

EAV modeling has been used by health and clinical software by decades because the
number of possible attributes like tests results and diagnostics are huge and
just a few of those attributes are acctualy filled (non-NULL).

=head2 When you dont't know your schema in advance

E-commerce solutions use EAV modeling to allow the definition of any kind of product
and still be able to do filtering/sorting of results based of product attributes.
For example, the entity 'HardDrive' would have atrributes 'capacity' and 'rpm',
while entity 'Monitor' would have attributes 'resolution' and 'contrast_ratio'.

=head2 To abstract the physical database layer

Many SaaS platforms use EAV modeling to offer database services to its custormers,
without exposing the physical database system.

=head2 When you need frequent changes to your schema

An open-schema data model can be useful for app prototyping.

=head1 DBIx::EAV CONCEPTS

=head2 EntityType

An L<EntityType|DBIx::EAV::EntityType> is the blueprint of an entity. Like a
Class in OOP. Each type has  a unique name, one or more attributes and zero or
more relationships. See L<DBIx::EAV::EntityType>.

=head2 Entity

An actual entity record (of some type) that has its own id and attribute values.
See L<DBIx::EAV::Entity>.

=head2 Attribute

Attributes are analogous to columns in traditional database modeling. Its the
actual named properties that describes an entity type. Every attribute has a
unique name and a data type. Unlike traditional table columns, adding/removing
attributes to an existing entity type is very easy and cheap.

=head2 Value

The actual attribute data stored in one of the value tables. There is one value
table for each data type.
See L<data_types>, L<DBIx::EAV::Schema>.

=head2 Physical Schema

This is the actual database tables used by the EAV system. Its represented by
L<DBIx::EAV::Schema>.

=head2 EAV Schema

Its the total set of Entity Types registered on the system, which form the
actual application business model.
See L<register_schema>.

=head2 ResultSet

Concept borrowed from L<DBIx::Class>, a ResultSet represents a query used for
fetching a set of entities of a type, as well as other CRUD operations on
multiple entities.

=head2 Cursor

A Cursor is used internally by the ResultSet to prepare, execute and traverse
through SELECT queries.

=head1 CONSTRUCTORS

=head2 new

=head2 connect

=head1 METHODS

=head2 register_schema

=over

=item Arguments: \%schema

=item Return value: none

=back

Register entity types specified in \%schema, where each key is the name of the
entity and the value is a hashref describing its attributes and relationships.
Described in detail in L<ENTITY DEFINITION>.


=head2 resultset

=over

=item Arguments: $name

=item Return value: L<$rs|DBIx::EAV::ResultSet>

=back

Returns a new L<resultset|DBIx::EAV::ResultSet> instance for
L<type|DBIx::EAV::EntityType> C<$name>.

    my $rs = $eav->resultset('Artist');

=head2 type

=over

=item Arguments: $name

=back

Returns the L<DBIx::EAV::EntityType> instance for type C<$name>. Dies if type
is not installed.

    my $types = $eav->type('Artist');

=head2 has_type

=over

=item Arguments: $name

=back

Returns true if L<entity type|DBIx::EAV::EntityType> C<$name> is installed.

=head2 schema

Returns the L<DBIx::EAV::Schema> instance representing the physical database schema.

=head2 table

Shortcut for C<< ->schema->table >>.

=head2 data_types

Returns an arrayref of data types known to the system. See L<new>.

=head2 has_data_type

=over

=item Arguments: $name

=back

Returns true if the data type C<$name> exists. See L<data_types>.

=head2 db_driver_name

Shortcut for C<< $self->dbh->{Driver}{Name} >>.

=head2 dbh_do

=over

=item Arguments: $stmt, \@bind?

=item Return Values: ($rv, $sth)

Prepares C<$stmt> and executes with the optional C<\@bind> values. Returns the
return value from execute C<$rv> and the actual statement handle C<$sth> object.

Set environment variable C<DBIX_EAV_TRACE> to 1 to get statements printed to
C<STDERR>.

=back

=head1 CASCADE DELETE

Since a single L<entity|DBIx::EAV::Entity>'s data is spread over several value
tables, we can't just delete the entity in a single SQL C<DELETE> command.
We must first send a C<DELETE> for each of those value tables, and one more for
the L<entity_relationships|DBIx::EAV::Schema/entity_relationships> table. If an
entity has attributes of 4 data types, and has any relationship defined, a total
of 6 (six!!) C<DELETE> commands will be needed to delete a single entity. Four
to the value tables, one for the entity_relationships and one for the actual
entities table).

Those extra C<DELETE> commands can be avoided by using database-level
C<ON DELETE CASCADE> for the references from the B<values> and
B<entity_relationships> tables to the B<entities> table.

If those contraints are in place, set L<database_cascade_delete|new> to C<1> and
those extra C<DELETE> commands will not be sent.

=head1 LICENSE

Copyright (C) Carlos Fernando Avila Gratz.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Carlos Fernando Avila Gratz E<lt>cafe@kreato.com.brE<gt>

=cut
