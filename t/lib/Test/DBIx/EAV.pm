package Test::DBIx::EAV;

use strict;
use warnings;
use DBI;
use FindBin;
use parent qw(Exporter);

our @EXPORT_OK = qw/ get_test_dbh empty_database read_file /;


sub empty_database {
    my $eav = shift;
    $eav->table('entity_relationships')->delete;
    $eav->table('value_'.$_)->delete for @{$eav->data_types};
    $eav->table('entities')->delete;
}


sub get_test_dbh {
    my (%options) = @_;
    my $driver = $ENV{TEST_DBIE_MYSQL} ? 'mysql' : 'SQLite';
    my $dbname = $driver eq 'mysql' ? $ENV{TEST_DBIE_MYSQL} : ':memory:';

    my $dbh = DBI->connect("dbi:$driver:dbname=$dbname",
        $ENV{TEST_DBIE_MYSQL_USER},
        $ENV{TEST_DBIE_MYSQL_PASSWORD});

    $dbh->{sqlite_see_if_its_a_number} = 1;

    $dbh;
}

sub read_file {
    my $filename = shift;
    open my $fh, '<', $filename or die "$!";
    return join '', <$fh>;
}



1;
