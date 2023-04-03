#!/usr/bin/env perl

use strict;
use warnings;

use DBI;

=head1 NAME

    Парсинг логов

=head1 DESCRIPTION

    В логе встречаются записи вида
    2012-02-13 14:39:22 1RwtJa-000AFJ-3B => :blackhole: <tpxmuwr@somehost.ru> R=blackhole_router
    Где видно, что адрес следует не после флага, а после строки :blackhole:
    Тем не менее, парсинг сделал в соответствии с ТЗ - добавив строку :blackhole: в поле address

=cut

use constant TIMESTAMP_REGEX => '^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}';

my $dsn = "DBI:mysql:database=gpb;host=localhost";
my $dbh = DBI->connect( $dsn, 'XXXXXX', 'XXXXXX',
    { PrintWarn => 0, PrintError => 0, RaiseError => 1 } );

my $file_name = shift @ARGV || 'out';

open my $fh, '<', $file_name || die "Can't open \"$file_name\": $!\n";

my @bad_lines = ();
my $good_lines = 0;
my @bad_timestamp = ();

while ( my $line = <$fh> ) {
    chomp $line;

    my ( $created, $str ) = $line =~ m/([^\s]+\s[^\s]+)\s(.*)/;

    # Если дата/время неправильного формата - запомним эту строку
    push( @bad_timestamp, $line ) unless $created =~ m/${\TIMESTAMP_REGEX}/;

    my ( $int_id, $flag, $address, $info ) = split( ' ', $str, 4 );
    
    eval {
        if ( $flag eq '<=' ) {
            my ($id) = $str =~ m{\sid=([^\s]+)};
            to_db_message( $created, $id || '', $int_id || '', $str || '' );
        } else {
            to_db_log( $created, $int_id || '', $str || '', $address || '' );
        }

        $good_lines++;

        1;
    } or do {
        push @bad_lines, {
            err  => $@,
            line => $line,
        };
    }
}
close $fh;

print "Exported $good_lines line(s) successfuly\n\n";

if ( @bad_timestamp ) {
    print "Bad timestamp ".(scalar @bad_timestamp)." line(s):\n";
    print join( "\n", @bad_timestamp )."\n\n";
}

print "Failed to export ".(scalar @bad_lines)." line(s):\n";
print join( "\n\n", map { 'Error: '.$_->{err}."Line: ".$_->{line} } @bad_lines )."\n\n";


sub to_db_message {
    my $sth = $dbh->prepare( 'INSERT INTO message (created, id, int_id, str) VALUES (?,?,?,?)' );
    $sth->execute(@_);
}

sub to_db_log {
    my $sth = $dbh->prepare( 'INSERT INTO log (created, int_id, str, address) VALUES (?,?,?,?)' );
    $sth->execute(@_);
}