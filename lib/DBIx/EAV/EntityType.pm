package DBIx::EAV::EntityType;

use Moo;
use strictures 2;



has 'core', is => 'ro', required => 1;
has 'id', is => 'ro', required => 1;
has 'name', is => 'ro', required => 1;
has '_static_attributes', is => 'ro', init_arg => 'static_attributes', default => sub { {} };
has '_attributes', is => 'ro', init_arg => 'attributes', default => sub { {} };
has '_relationships', is => 'ro', init_arg => 'relationships', default => sub { {} };
has 'parent', is => 'ro', predicate => 1;


sub parents {
    my ($self) = @_;
    return () unless $self->has_parent;
    my @parents;
    my $parent = $self->parent;
    while ($parent) {
        push @parents, $parent;
        $parent = $parent->parent;
    }

    @parents;
}

sub is_type {
    my ($self, $type) = @_;
    return 1 if $self->name eq $type;
    foreach my $parent ($self->parents) {
        return 1 if $parent->name eq $type;
    }
    0;
}



sub has_attribute {
    my ($self, $name) = @_;
    return 1 if exists $self->_attributes->{$name} || exists $self->_static_attributes->{$name};
    return 0 unless $self->has_parent;

    my $parent = $self->parent;
    while ($parent) {
        return 1 if $parent->has_own_attribute($name);
        $parent = $parent->parent;
    }

    0;
}

sub has_static_attribute {
    my ($self, $name) = @_;
    exists $self->_static_attributes->{$name};
}

sub has_own_attribute {
    my ($self, $name) = @_;
    exists $self->_attributes->{$name} || exists $self->_static_attributes->{$name};
}

sub has_inherited_attribute {
    my ($self, $name) = @_;
    return 0 unless $self->has_parent;
    my $parent = $self->parent;
    while ($parent) {
        return 1 if exists $parent->_attributes->{$name};
        $parent = $parent->parent;
    }
    0;
}

sub attribute {
    my ($self, $name) = @_;

    # our attr
    return $self->_attributes->{$name}
        if exists $self->_attributes->{$name};

    return $self->_static_attributes->{$name}
        if exists $self->_static_attributes->{$name};

    # parent attr
    my $parent = $self->parent;
    while ($parent) {
        return $parent->_attributes->{$name}
            if exists $parent->_attributes->{$name};
        $parent = $parent->parent;
    }

    # unknown attribute
    die sprintf("Entity '%s' does not have attribute '%s'.", $self->name, $name);
}

sub attributes {
    my ($self, %options) = @_;
    my @items;

    # static
    push @items, values %{$self->_static_attributes}
        unless $options{no_static};

    # own
    push @items, values %{$self->_attributes}
        unless $options{no_own};

    # inherited
    unless ($options{no_inherited}) {

        my $parent = $self->parent;
        while ($parent) {
            push @items, values %{$parent->_attributes};
            $parent = $parent->parent;
        }
    }

    return $options{names} ? map { $_->{name} } @items : @items;
}




sub has_own_relationship {
    my ($self, $name) = @_;
    exists $self->_relationships->{$name};
}

sub has_relationship {
    my ($self, $name) = @_;
    return 1 if exists $self->_relationships->{$name};
    return 0 unless $self->has_parent;

    my $parent = $self->parent;
    while ($parent) {
        return 1 if $parent->has_own_relationship($name);
        $parent = $parent->parent;
    }

    0;
}

sub relationship {
    my ($self, $name) = @_;

    # our
    return $self->_relationships->{$name}
        if exists $self->_relationships->{$name};

    # parent
    my $parent = $self->parent;
    while ($parent) {
        return $parent->_relationships->{$name}
            if exists $parent->_relationships->{$name};
        $parent = $parent->parent;
    }

    # unknown
    die sprintf("Entity '%s' does not have relationship '%s'.", $self->name, $name);
}

sub relationships {
    my ($self, %options) = @_;

    # ours
    my @items = values %{$self->_relationships};

    # inherited
    unless ($options{no_inherited}) {

        my $parent = $self->parent;
        while ($parent) {
            push @items, values %{$parent->_relationships};
            $parent = $parent->parent;
        }
    }

    return $options{names} ? map { $_->{name} } @items : @items;
}


sub register_relationship {
    my ($self, $reltype, $rel) = @_;

    $rel = { entity => $rel } if ref $rel ne 'HASH';

    die sprintf("Error: invalid %s relationship for entity '%s': missing 'entity' parameter.", $reltype, $self->name)
        unless $rel->{entity};

    my $other_entity = $self->core->type($rel->{entity});


    my %row_data = (
        left_entity_type_id  => $self->id,
        right_entity_type_id => $other_entity->id,
        name => $rel->{name},
        "is_$reltype" => 1
    );

    # build rel names
    if ($reltype eq 'has_many') {

        $row_data{name} ||= lc Lingua::EN::Inflect::PL($rel->{entity});
        $rel->{incoming_name} = lc $self->name;
    }
    elsif ($reltype eq 'many_to_many') {

        $row_data{name} ||= lc Lingua::EN::Inflect::PL($rel->{entity});
        $rel->{incoming_name} = lc Lingua::EN::Inflect::PL($self->name);
    }
    elsif ($reltype eq 'has_one') {

        $row_data{name} ||= lc $rel->{entity};
        $rel->{incoming_name} = lc $self->name;
    }
    else {
        die "Invalid relationship type '$reltype'.";
    }

    my $relationships_table = $self->core->table('relationships');
    my $row = $relationships_table->select_one(\%row_data);

    if ($row) {
        # update description
    }
    else {
        my $id = $relationships_table->insert(\%row_data);
        $row = $relationships_table->select_one({ id => $id });
        die sprintf("Database error while registering belongs_to relationship '%s' for entity '%s'", $rel->{name}, $self->name)
            unless $row;
    }

    # install relationship
    $row->{entity} = $other_entity->name;
    $row->{incoming_name} = $rel->{incoming_name};
    $self->_install_relationship($row->{name}, $row);

    if ($rel->{incoming_name}) {
        my %their_rel = (%$row, entity => $self->name, is_right_entity => 1);
        $their_rel{incoming_name} = $their_rel{name}; # swap names
        $their_rel{name} = $rel->{incoming_name};
        $other_entity->_install_relationship($rel->{incoming_name}, \%their_rel);
    }


    $row;
}

sub _install_relationship {
    my ($self, $relname, $rel) = @_;

    die sprintf("Entity '%s' already has relationship '%s'.", $self->name, $relname)
        if exists $self->_relationships->{$relname};

    $self->_relationships->{$relname} = $rel;
}



sub prune_attributes {
    my ($self, $names) = @_;
    # TODO implement prune_attributes
}

sub prune_relationships {
    my ($self, $names) = @_;
    # TODO implement prune_relationships
}









1;


__END__

=encoding utf-8

=head1 NAME

DBIx::EAV::EntityType - An entity type. Its attributes and relationships.

=head 1 SYNOPSIS

=head 1 DESCRIPTION

=head 1 METHODS

=head1 LICENSE

Copyright (C) Carlos Fernando Avila Gratz.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Carlos Fernando Avila Gratz E<lt>cafe@kreato.com.brE<gt>

=cut
