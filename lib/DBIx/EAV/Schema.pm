package DBIx::EAV::Schema;

use Moo;
use Carp 'croak';
use Scalar::Util 'blessed';
use DBIx::EAV::Table;
use SQL::Translator;
use constant {
    SQL_DEBUG => $ENV{DBIX_EAV_TRACE}
};


my %driver_to_producer = (
    mysql => 'MySQL'
);


has 'dbh', is => 'ro', required => 1;
has 'table_prefix', is => 'ro', required => 1;
has 'data_types', is => 'ro', required => 1;
has 'tenant_id', is => 'ro';
has 'translator', is => 'ro', init_arg => undef, lazy => 1, builder => 1;
has 'id_field_type', is => 'ro', default => 'bigint';
has 'static_attributes', is => 'ro', default => sub { [] };
has '_tables', is => 'ro', default => sub { {} };


sub _build_translator {
    my $self = shift;

    my $sqlt = SQL::Translator->new(
        from => sub { $self->_build_sqlt_schema($_[0]->schema) }
    );

    # translate asap to load our schema
    $sqlt->translate;

    $sqlt;
}

sub _build_sqlt_schema {
    my ($self, $schema) = @_;

    my @schema = (

        entity_types => {
            columns => ['id', $self->tenant_id ? 'tenant_id' : (), 'name:varchar:255'],
            index   => [$self->tenant_id ? 'tenant_id' : ()],
            unique  => {
                name => [$self->tenant_id ? 'tenant_id' : (),'name']
            }
        },

        entities => {
            columns => [qw/ id entity_type_id  /, @{ $self->static_attributes } ],
            fk      => { entity_type_id => 'entity_types' }
        },

        attributes => {
            columns => [qw/ id entity_type_id name:varchar:255 data_type:varchar:64 /],
            fk      => { entity_type_id => 'entity_types' }
        },

        relationships => {
            columns => [qw/ id name:varchar:255 left_entity_type_id right_entity_type_id is_has_one:bool::0 is_has_many:bool::0 is_many_to_many:bool::0 /],
            fk      => { left_entity_type_id => 'entity_types', right_entity_type_id => 'entity_types' },
            unique  => {
                name => ['left_entity_type_id','name']
            }
        },

        entity_relationships => {
            columns => [qw/ relationship_id left_entity_id right_entity_id /],
            pk => [qw/ relationship_id left_entity_id right_entity_id /],
            fk => {
                relationship_id => 'relationships',
                left_entity_id  => 'entities',
                right_entity_id => 'entities',
            }
        },

        type_hierarchy => {
            columns => [qw/ parent_type_id child_type_id /],
            pk => [qw/ parent_type_id child_type_id /],
        },

        map {
            ("value_$_" => {
                columns => [qw/ entity_id attribute_id /, 'value:'.$_],
                fk => {
                    entity_id    => { table => 'entities', cascade_delete => 1 },
                    attribute_id => 'attributes'
                }
            })
        } @{ $self->data_types }
    );

    for (my $i = 0; $i < @schema; $i += 2) {

        # add table
        my $table_name = $schema[$i];
        my $table_schema = $schema[$i+1];
        my $table = $schema->add_table( name => $self->table_prefix . $table_name )
            or die $schema->error;

        # add columns
        foreach my $col ( @{ $table_schema->{columns} }) {

            my $field_params = ref $col ? $col : do {

                my ($name, $type, $size, $default) = split ':', $col;
                +{
                    name => $name,
                    data_type => $type,
                    size => $size,
                    default_value => $default
                }
            };

            $field_params->{data_type} = $self->id_field_type
                if $field_params->{name} =~ /(?:^id$|_id$)/;

            $field_params->{is_auto_increment} = 1
                if $field_params->{name} eq 'id';

            $field_params->{is_nullable} //= 0;

            $table->add_field(%$field_params)
                or die $table->error;
        }

        # # primary key
        my $pk = $table->get_field('id') ? 'id' : $table_schema->{pk};
        $table->primary_key($pk) if $pk;

        # # foreign keys
        foreach my $fk_column (keys %{ $table_schema->{fk} || {} }) {

            my $params = $table_schema->{fk}->{$fk_column};
            $params = { table => $params } unless ref $params;

            $table->add_constraint(
                name => join('_', 'fk', $table_name, $fk_column, $params->{table}),
                type => 'foreign_key',
                fields => $fk_column,
                reference_fields => 'id',
                reference_table => $self->table_prefix . $params->{table},
                on_delete => $params->{cascade_delete} ? 'CASCADE' : 'NO ACTION'
            );
        }

        # # unique constraints
        foreach my $name (keys %{ $table_schema->{unique} || {} }) {

            $table->add_index(
                name => join('_', 'unique', $table_name, $name),
                type => 'unique',
                fields => $table_schema->{unique}{$name},
            );
        }

        # # index
        foreach my $colname (@{ $table_schema->{index} || [] }) {

            $table->add_index(
                name => join('_', 'idx', $table_name, $colname),
                type => 'normal',
                fields => $colname,
            );
        }
    }

    return 1;
}


sub get_ddl {
    my ($self, $producer) = @_;

    unless ($producer) {

        my $driver = $self->dbh->{Driver}{Name};
        $producer = $driver_to_producer{$driver} || $driver;
    }


    $self->translator->producer($producer);
    $self->translator->translate;
}


sub deploy {
    my $self = shift;
    my %options = ( @_, no_comments => 1 );

    $self->translator->$_($options{$_})
        for keys %options;

    $self->dbh_do($_)
        for grep { /\w/ } split ';', $self->get_ddl;
}


sub dbh_do {
    my ($self, $stmt, $bind) = @_;

    if (SQL_DEBUG) {
        my $i = 0;
        print STDERR "$stmt";
        print STDERR $bind ? sprintf(": %s\n", join('  ', map { $i++.'='.$_ } @{ $bind || [] }))
                           : ";\n";
    }

    my $sth = $self->dbh->prepare($stmt);
    my $rv = $sth->execute(ref $bind eq 'ARRAY' ? @$bind : ());
    die $sth->errstr unless defined $rv;

    return ($rv, $sth);
}

sub table {
    my ($self, $name) = @_;

    return $self->_tables->{$name}
        if exists $self->_tables->{$name};

    my $table_schema = $self->translator->schema->get_table($self->table_prefix.$name);

    croak "Table '$name' does not exist."
        unless $table_schema;

    $self->_tables->{$name} = DBIx::EAV::Table->new(
        dbh       => $self->dbh,
        tenant_id => $self->tenant_id,
        name      => $table_schema->name,
        columns   => [ $table_schema->field_names ]
    );
}




1;


__END__

=encoding utf-8

=head1 NAME

DBIx::EAV::Schema - Describes the physical EAV database schema.

=head1 SYNOPSIS

    my $schema = DBIx:EAV::Schema->new(
        dbh          => $dbh,               # required
        tables       => \%tables            # required
        tenant_id    => $tenant_id,         # default undef
        table_prefix => 'my_eav_',          # default 'eav_'
    );

=head1 DESCRIPTION

This class represents the physical eav database schema. Will never need to
instantiate an object of this class directly.

=head1 TABLES

This section describes the required tables and columns for the EAV system.

=head2 entity_types

This table stores all entities. All columns of of this table are presented as
static attributes for all entity types. So you can add any number of columns in
addition to the required ones.

=head2 attributes

=head2 relationships

=head2 type_hierarchy

=head2 entities

=head2 entity_relationships

=head2 <data_type>_values

=head1 METHODS

=head2 table

    my $table = $schema->table($name);

Returns a L<DBIx::EAV::Table> representing the table $name.

=head1 LICENSE

Copyright (C) Carlos Fernando Avila Gratz.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Carlos Fernando Avila Gratz E<lt>cafe@kreato.com.brE<gt>

=cut
