use strict;
use warnings;
use feature 'say';
use utf8;
use Encode;

use WWW::Lingr;
use DateTime;
use DateTime::Format::ISO8601;
use Text::Trim;

our $WAIT_MIN = 10;

my $lingr  = WWW::Lingr->new( room => q{perl_jp}) ;
my $last_epoch = 0; #DateTime->now( time_zone => 'Asia/Tokyo')->add( minutes =>  $WAIT_MIN * -1)->epoch;
while(1){
    my $data   = $lingr->get();
    for my $row (@$data){
        my $timestamp = Text::Trim::trim($row->{timestamp});
        my $dt = DateTime::Format::ISO8601->parse_datetime($timestamp);
        if($dt->epoch() > $last_epoch){
                my $line = sprintf("[%s] %s:%s", (
                    $dt->add( hours =>  +9)->hms,
                    $row->{nickname},
                    $row->{description},
                )
            );
            say Encode::encode_utf8 $line;
        }
    }
    $last_epoch = DateTime->now( time_zone => 'Asia/Tokyo')->epoch;
    sleep 60 * $WAIT_MIN;
}
