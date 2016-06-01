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

    my $driver = $ENV{TEST_DBIE_MYSQL} ? 'mysql' : 'SQLite';
    my $dbname = $driver eq 'mysql' ? $ENV{TEST_DBIE_MYSQL} : ':memory:';

    my $dbh = DBI->connect("dbi:$driver:dbname=$dbname",
        $ENV{TEST_DBIE_MYSQL_USER},
        $ENV{TEST_DBIE_MYSQL_PASSWORD});

    $dbh->{sqlite_see_if_its_a_number} = 1;

    open my $fh, '<', "$FindBin::Bin/eav-schema.sql"
        or die "open error: $!";

    my @lines = <$fh>;
    my $content = join '', @lines;

    $dbh->do($_) for grep { /\w/ }
                    #  map { diag $_; $_; }
                     map { $driver eq 'SQLite' ? _to_sqlite($_) : $_ } split ';', $content;

    $dbh;
}

sub read_file {
    my $filename = shift;
    open my $fh, '<', $filename or die "$!";
    return join '', <$fh>;
}


sub _to_sqlite {
    my $cmd = shift;
    return '' if $cmd =~ /^\s*SET/m;
    $cmd =~ s/AUTO_INCREMENT//;
    $cmd =~ s/(UNIQUE|) INDEX.*$//s;
    $cmd =~ s/\),$/))/m;
    $cmd;
}




1;
