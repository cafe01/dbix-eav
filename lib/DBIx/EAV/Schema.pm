package DBIx::EAV::Schema;

use Moo;
use Carp 'croak';
use Scalar::Util 'blessed';
use DBIx::EAV::Table;

has 'dbh', is => 'ro', required => 1;
has 'table_prefix', is => 'ro', required => 1;
has 'tenant_id', is => 'ro';
has 'tables', is => 'ro', required => 1;


sub table {
    my ($self, $name) = @_;
    my $tables = $self->tables;

    croak "Table '$name' does not exist."
        unless exists $tables->{$name};

    return $tables->{$name} if blessed $tables->{$name};

    my $columns = $tables->{$name};

    $tables->{$name} = DBIx::EAV::Table->new(
        dbh  => $self->dbh,
        name => $self->table_prefix . $name,
        tenant_id => $self->tenant_id,
        columns => $columns
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

This class represents the physical eav database schema. Will never need to instantiate
an object of this class directly.

=head1 TABLES

This section describes the required tables and columns for the EAV system.

=head2 entity_types

This table stores all entities. All columns of of this table are presented as
static attributes for all entity types. So you can add any number of columns in
addition to the required ones.

=over

=item Columns:

=over

=item id INT NOT NULL AUTOINCREMENT

=item entity_type_id INT

=item created_at DATETIME

=item updated_at DATETIME

=back

=item Foreing keys:

=over

=item entity_type_id REFERENCES entity_types.id

=back

=head2 attributes

=head2 relationships

=head2 type_hierarchy

=head1 METHODS

=head2 table

    my $table = $schema->table($name);

Returns a L<DBIx::EAV::Table> representing the table $name.

=head2 REQUIRED SCHEMA

=head1 LICENSE

Copyright (C) Carlos Fernando Avila Gratz.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Carlos Fernando Avila Gratz E<lt>cafe@kreato.com.brE<gt>

=cut
