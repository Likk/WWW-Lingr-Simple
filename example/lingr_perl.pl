use strict;
use warnings;
use feature 'say';
use utf8;
use Encode;

use WWW::Lingr::Simple;
use HTTP::Date;
use Text::Trim;

our $WAIT_MIN = 10;

my $lingr  = WWW::Lingr::Simple->new( room => q{perl_jp}) ;
my $last_id = 0;
while(1){
    my $data   = $lingr->get();
    for my $row (@$data){
        my $time = HTTP::Date::str2time($row->{timestamp});
        if($last_id < $row->{id} + 0){
            print Encode::encode_utf8(
                sprintf("[%s] %s:%s\n", (
                        HTTP::Date::time2iso($time),
                        $row->{speaker},
                        $row->{description},
                    )
                )
            );
        }
        $last_id = $row->{id} + 0;
    }
    sleep 60 * $WAIT_MIN;
}
