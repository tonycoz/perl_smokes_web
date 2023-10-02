package SmokeReports::Schema::ResultSet::ParsedReport;
use v5.32.0;
use SmokeReports::Sensible;
use parent 'DBIx::Class::ResultSet';

sub insert_columns($self) {
    $self->result_class->insert_columns;
}

sub update_columns($self) {
    $self->result_class->update_columns;
}

1;
