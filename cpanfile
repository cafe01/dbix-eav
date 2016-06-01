requires 'perl', '5.008001';

requires 'Moo';
requires 'DBI';
requires 'strictures';
requires 'Scalar::Util';
requires 'SQL::Abstract';
requires 'Lingua::EN::Inflect', '1.899';

on 'test' => sub {

    requires 'Test::More', '0.98';
    requires 'YAML', '1.15';
    requires 'DBD::SQLite', '1.50';

};
