package SmokeReports::Schema::ResultSet::ParsedReport;
use v5.32.0;
use SmokeReports::Sensible;
use parent 'DBIx::Class::ResultSet';

sub insert_columns($self) {
    grep !/^(?:id|need_update)$/, $self->result_source->columns;
}

sub update_columns($self) {
    grep !/^(?:nntp_id|smokedb_id)$/, $self->insert_columns;
}

1;
