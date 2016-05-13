#! /usr/bin/perl
#

use 5.014;
use strict;
use warnings;
use autodie;
use DBI;
use encoding "utf-8";
use Encode qw/encode decode/;
use Spreadsheet::WriteExcel;
use Data::Dumper;

my %hash = (
    'yidao'=>['cases', 'coures', 'articles'],
    'other'=>['hello', 'world'],
);

my ($pro_id, $date_back) = @ARGV;
if (defined($pro_id) && exists($hash{$pro_id})){
    my $dbh = DBI->connect("DBI:mysql:database=yidao;host=localhost",
                       "root", "", {'RaiseError' => 1});
    $dbh->do("SET NAMES utf8");

    my $workbook = Spreadsheet::WriteExcel->new($pro_id.'.xls');
    $workbook->set_properties(utf8 => 1,);

    my $array = $hash{$pro_id};
    foreach my $item (@$array){
        my ($datas, $list_pv, $list_pv_week) = &makeData($dbh, $item, $date_back);
        my @whole_datas = ($datas, $list_pv, $list_pv_week);
        makeSheet($workbook, $item, \@whole_datas);

    }
    $workbook->close();
    $dbh->disconnect();
}

sub makeData {
    my ($dbh, $table_name, $date_back) = @_;
    my $list_data = $dbh->prepare("
        select id,title,DATE(created_at) as created_at
        from $table_name where is_deleted = 0 and status > 0;");
    $list_data->execute();

    my @ids, my @datas;
    while(my @row = $list_data->fetchrow_array()){
        push @ids,$row[0];
        push @datas,[@row];
    }
    $list_data->finish();

    my @list_pv;
    my $list_pv = $dbh->prepare("
        select tid, count(*) as PV, COUNT(DISTINCT `logs`.user_id) AS UV from `logs`
        where `logs`.tname = '$table_name' and tid in (" . join(',', @ids) . ")
        GROUP BY `logs`.tid;");
    $list_pv->execute();
    while(my @row = $list_pv->fetchrow_array()){
        push @list_pv, [@row];
    }
    $list_pv->finish();

    my @list_pv_week;
    my $list_pv_week = !defined($date_back) ? 0 : $dbh->prepare("
        select tid, count(*) as PV_WEEK, COUNT(DISTINCT `logs`.user_id) AS UV_WEEK from `logs`
        where `logs`.tname = '$table_name' and tid in (" . join(',', @ids) . ")
        AND DATE(`logs`.created_at) > '$date_back'
        GROUP BY `logs`.tid;");
    if (defined($date_back)){
        $list_pv_week->execute();
        while(my @row = $list_pv_week->fetchrow_array()){
            push @list_pv_week, [@row];
        }
        $list_pv_week->finish();
    }
    return (\@datas, \@list_pv, \@list_pv_week);
}


sub makeSheet {
    my ($workbook, $table, $whole_datas) = @_;
    my $worksheet = $workbook->add_worksheet($table);

    my $row_ = 1;
    $worksheet->write(0, 0, 'tid');
    $worksheet->write(0, 1, 'title');
    $worksheet->write(0, 2, 'created_at');
    $worksheet->write(0, 3, 'pv');
    $worksheet->write(0, 4, 'uv');
    $worksheet->write(0, 5, 'pv_week');
    $worksheet->write(0, 6, 'uv_week');

    my ($datas, $list_pv, $list_pv_week) = @$whole_datas;
    foreach my $data (@$datas){
        $worksheet->write($row_, 0, @$data[0]);
        $worksheet->write($row_, 1, decode('utf8', @$data[1]));
        $worksheet->write($row_, 2, @$data[2]);

        foreach (@$list_pv){
            if (@$data[0] == @$_[0]){
                $worksheet->write($row_, 3, @$_[1]);
                $worksheet->write($row_, 4, @$_[2]);
                last;
            }
        }

        if ($list_pv_week){
            foreach (@$list_pv_week){
                if (@$data[0] == @$_[0]){
                    $worksheet->write($row_, 5, @$_[1]);
                    $worksheet->write($row_, 6, @$_[2]);
                    last;
                }
            }
        }
        $row_++;
    }
}

