requires 'perl', '5.010';

requires 'Moo';
requires 'DBI';
requires 'strictures', '2.000003';
requires 'Scalar::Util';
requires 'SQL::Abstract';
requires 'SQL::Translator', '0.11021';
requires 'Lingua::EN::Inflect', '1.899';

on 'test' => sub {

    requires 'Test2::Suite';
    requires 'YAML', '1.15';
    requires 'DBD::SQLite', '1.50';

};
