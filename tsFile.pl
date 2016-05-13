#! /usr/bin/perl

use 5.014;
use strict;
use lib "/root/perl5/lib/perl5";
use autodie;
use warnings;

open FILE,"</var/log/secure";
my $i=0;
my %fuckIp=();

while(<FILE>){
    if($_ =~ /Failed password.*from (\S+)/){
        if(!exists($fuckIp{$1})){
            $fuckIp{$1}=1;
            #print "$1\n";
        }
    }
}
close FILE;

sub isDropIp {
    my ($kip) = @_;
    my @kips = `firewall-cmd --list-rich-rule`;
    if (@kips) {
        foreach my $ipStr (@kips){
            if ($ipStr =~ /address=\"(\S+)\"/) {
                if ($kip eq $1) {
                    #print "ip: $1";
                    return 1;
                }
            }
        }
    }
    return 0;
}

if(%fuckIp){
    foreach my $kip (keys %fuckIp){
        next if &isDropIp($kip);
        my $cmd = "cat /var/log/secure |grep \"Failed password for\" |grep \"$kip\" | wc -l";
        my $times = `$cmd`;
        #print "$kip appear $times";
        $fuckIp{$kip}=$times;
    }

    while(my ($ip, $pv) = each(%fuckIp)){
        if($pv>30){
            print "the $ip appear $pv times!\n";
            my $cmd = "firewall-cmd";
            $cmd .= " --zone=public --add-rich-rule='rule family=\"ipv4\" source address=\"$ip\" drop'";
            system($cmd);
            sleep(1);
        }
    }
    #system("systemctl restart firewalld");
}







