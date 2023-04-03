#!/usr/bin/env perl

use strict;
use warnings;

use CGI;
use DBI;
use Template;

=head1 NAME

    Поиск в логах по адресу получателя

=head1 DESCRIPTION

    В ТЗ сказано, что на html-странице должно быть поле для ввода адреса получателя.
    А в таблицу message мы складывали строки с флагом <=, то есть, прибытия сообщения.
    Из ТЗ известно, что в это случае за флагом следует адрес отправителя. 
    Таким образом получается, что в таблицу message попадают только строки с адресами отправителей,
    а т.к. мы ищем среди адресов получателей, то выборку следует делать только по таблице log.
    Если бы этого оганичения не было, запрос выглядел бы примерно так:

    SELECT *
    FROM   (SELECT created,
                int_id,
                str
            FROM   message
            UNION
            SELECT created,
                int_id,
                str
            FROM   log) message_log_tbl
    WHERE  str LIKE "%somehost.ru%"
    ORDER  BY int_id,
            created
    LIMIT  100;  

=cut

use constant LIMIT => 100;


my $dsn = "DBI:mysql:database=gpb;host=localhost";
my $dbh = DBI->connect( $dsn, 'XXXXXX', 'XXXXXX' );

my $tt = Template->new( {
    INCLUDE_PATH => '.',
    INTERPOLATE  => 1,
} ) or die "$Template::ERROR\n";

my $cgi = CGI->new();  
my $address = $cgi->param('address');

my $data = {
	title => 'Database search',
};

if ($address) {
    my $sth = $dbh->prepare('SELECT created, int_id, str FROM log where address like ? ORDER BY int_id, created limit ?')
        or die $DBI::errstr;
    $sth->bind_param(1, "%$address%");
    $sth->bind_param(2, LIMIT() + 1);
    $sth->execute() or die $DBI::errstr;

    my $list = $sth->fetchall_arrayref({});

    $data->{log} = $list;
    $data->{address} = $address;
    if ( scalar(@$list) > LIMIT() ) {
        pop @$list;
        $data->{limit_ex_message} = 'Количество найденных строк превышает лимит ' . LIMIT();
    }

}

print "Content-type: text/html\r\n\r\n";
$tt->process('main.tt', $data) or die $tt->error(), "\n";

