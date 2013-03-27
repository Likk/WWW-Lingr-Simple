#!/user/bin/env perl
use strict;
use warnings;
use utf8;
use Encode;
use Getopt::Long;
use HTTP::Date;
use IO::Socket;
use IO::Select;
use Text::Trim;
use WWW::Lingr::Simple;

use constant {
    # foreground color
    BLACK  => "\033[30m",
    RED    => "\033[31m",
    GREEN  => "\033[32m",
    YELLOW => "\033[33m",
    BLUE   => "\033[34m",
    PURPLE => "\033[35m",
    CYAN   => "\033[36m",
    WHITE  => "\033[37m",
    # background color
    BLACKB  => "\033[40m",
    REDB    => "\033[41m",
    GREENB  => "\033[42m",
    YELLOWB => "\033[43m",
    BLUEB   => "\033[44m",
    PURPLEB => "\033[45m",
    CYANB   => "\033[46m",
    WHITEB  => "\033[47m",
    # bold
    B       => "\033[1m",
    BOFF    => "\033[22m",
    # italics
    I       => "\033[3m",
    IOFF    => "\033[23m",
    # underline
    U       => "\033[4m",
    UOFF    => "\033[24m",
    # invert
    R       => "\033[7m",
    ROFF    => "\033[27m",
    # reset
    RESET  => "\033[0m",
};

Getopt::Long::GetOptions(
    '-port|p=s'              => \my $port,
    '-lingr_user|user=s'     => \my $user,
    '-lingr_password|pass=s' => \my $pass,
    '-lingr_room|r=s'   => \my $room,
);

my $lingr  = WWW::Lingr::Simple->new(
    room     => $room,
    login_id => $user,
    password => $pass,
) ;
$lingr->login();

my $last_id  = 0;
my $interval = 60;

if(my $pid = fork()) {#fork
    #make server obj
    my $server_socket = IO::Socket::INET->new(
        LocalPort => $port || 59634,
        Proto     => 'tcp',
        Listen    => 1,
        Reuse     => 1,
    );
    die("not support Socke:$!") unless $server_socket;
    my $client_socket = $server_socket->accept();
    while(1){
        my $udpSel = IO::Select->new;
        $udpSel->add($client_socket);
        if(IO::Select->select($udpSel, undef, undef, $interval)) {
            my $msg = <$client_socket>||'';
            $msg =~ s/[\r\n]//g;
            $msg = Text::Trim::trim($msg);
            if($msg ne ''){
                last if $msg eq 'quit';
                cmd_io($msg);
            }
        }
        timeline();
    }
    exit(0);
}elsif (defined $pid){
    sleep 1;
    my $socket = IO::Socket::INET->new(
      PeerAddr => 'localhost',
      PeerPort => $port || 59634,
      Proto    => 'tcp',
      TimeOut  => 10
    );
    die("not support Socke:$!") unless $socket;
    print $socket " \n";
    while(my $in = <STDIN>||''){
        print "\r";
        chomp $in;
        print $socket $in."\n";
        last if $in eq 'quit';
    }
    exit(0);
}else{
    die "Can't fork: $\n";
}


sub cmd_io {
    my $in = shift;
    my $code = {
        say    => qr{^/(.*)$},
        chroom => qr{^/chroom\s(.*)?$},
        cls    => qr{^/clear$},
    };
    if(0){
    }
    elsif($in =~ $code->{chroom}){
        $lingr->room($1);
        print "change room $1\n";
    }
    elsif($in =~ $code->{cls}){
        print `clear`;
    }
    elsif($in =~ $code->{say}){
        $lingr->say($1);
        return 1;
    }
    return;
}

sub timeline {
    my $data   = $lingr->get();
    for my $row (@$data){
        my $time = HTTP::Date::str2time($row->{timestamp});
        if($last_id < $row->{id} + 0){
            print Encode::encode_utf8(
                sprintf("%s[%s]%s %s%s%s %s%-10s%s:%s %s(%s)%s\n", (
                        YELLOW,
                        HTTP::Date::time2iso($time),
                        RESET,
                        GREEN,
                        $lingr->room,
                        RESET,
                        CYAN,
                        $row->{speaker},
                        RESET,
                        $row->{description},
                        PURPLE,
                        $row->{id},
                        RESET,
                    )
                )
            );
            $last_id = $row->{id} + 0;
        }
    }
}
