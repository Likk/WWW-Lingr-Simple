package WWW::Lingr::Simple;

=encoding utf8

=head1 NAME

  WWW::Lingr::Simple - lingr.com client for perl.

=head1 SYNOPSIS

  use WWW::Lingr::Simple;
  use YAML;
  my $lingr = WWW::Lingr->new( room => q{perl_jp} );
  my $log   = $lingr->get;
  warn YAML::Dump $log;

=head1 DESCRIPTION

  WWW::Lingr::Simple is scraping library client for perl at lingr.com.

=cut

use strict;
use warnings;
use utf8;
use Carp;
use Encode;
use Try::Tiny;
use URI::Escape;
use Web::Scraper;
use WWW::Mechanize;
use Class::Accessor::Lite(
    new => 1,
    rw  => [ qw(room) ],
);

=head1 PACKAGE GLOBAL VARIABLE

=over

=item B<VERSION>

  version.

=item B<BASE_URL>

  lingr.com base top url.

=item B<ROOM_PATH>

  chat room archives pattern.

=item B<CHAT_PATH>

  chat room pattern

=item B<SAY_PATH>

  update pattern

=back

=cut

our $VERSION   = '2.00';
our $BASE_URL  = q{http://lingr.com/};
our $ROOM_PATH = q{room/__NAME__/archives};
our $CHAT_PATH = q{room/__NAME__/chat};
our $SAY_PATH  = q{api/room/say};

=head1 CONSTRUCTOR AND STARTUP

=head2 new

Creates and returns a new WWW::Lingr::Simple object.

  my $lingr = WWW::Lingr::Simple->new(
        #require.
        room     => q{room_name},
        #optional, but require when you say.
        login_id => q{lingr login id},
        password => q{lingr password},
  );

=head1 Accessor

=over

=item B<room>

  chat room name.

=item B<mech>

  WWW::Mechanize object.

=back

=cut

sub mech {
    my $self = shift;
    $self->{__mech} ||= WWW::Mechanize->new(
        agent => 'Mozilla/5.0 (Windows NT 6.1; rv:19.0) Gecko/20100101 Firefox/19.0',
        cookie_jar => {},
    );
}

=head1 METHODS

=head2 get

  get logs at the chat room.

  my $chat_log_array_ref = $lingr->get();
  #or
  my $chat_log_array_ref = $lingr->get(q{perl_jp});

  for my $log (@$chat_log_array_ref){
      print "$log->{nickname}: $log->{description}"
  }

=cut

sub get {
    my $self     = shift;
    my $room     = shift || $self->room;
    my $room_url = $ROOM_PATH;
    $room_url    =~ s{__NAME__}{$room};
    my $res      = $self->mech->get($BASE_URL . $room_url);

    $self->_parse($res->decoded_content());
}

=head2 login

  sign in at lingr.com

  my $lingr->new(
      room     => q{room_name},
      login_id => q{lingr login id},
      password => q{lingr password},
  );
  $lingr->login();

=cut

sub login {
    my $self = shift;
    my $authen_params = $self->_get_authen_params();
    my $params = {
        'signin[user]'        => $self->{login_id},
        'signin[password]'    => $self->{password},
        %$authen_params
    };

    my $res = $self->mech->post('http://lingr.com/signin', $params);
}

=head2 root

  access at root page.

=cut

sub root {
    my $self = shift;
    my $res  = $self->mech->get($BASE_URL);
    warn $res->decoded_content();
}


=head2 say

post at chat room.

=cut

sub say {
    my $self = shift;
    my $text = shift;
    my $mech = $self->mech;
    my $chat_url = $CHAT_PATH;
    $chat_url =~ s{__NAME__}{$self->{room}};
    my $res = $mech->get($BASE_URL . $chat_url);
    my $content = $res->decoded_content();
    my $session_id;
    if($content =~m{Lingr.session_id = '(\w+)'}){
        $session_id = $1;
    }
    $mech->add_header('X-Requested-With' => 'XMLHttpRequest');
    my $get_string = sprintf(
        $BASE_URL .
        $SAY_PATH .
        "?session=%s&room=%s&nickname=%s&text=%s",
        (
            $session_id,
            $self->room,
            $self->{login_id},
            Encode::decode_utf8($text),
        )
    );
    $res = $mech->get($get_string);
    $mech->delete_header('X-Requested-With');
    return $res->decoded_content;
}

=head1 PRIVATE METHODS

=over

=item b<_get_authenticity_params>

scrape parameter at authenticity for sign in

=cut

sub _get_authen_params {
    my $self    = shift;
    my $param   = {};
    my $res     = $self->mech->get($BASE_URL . 'signin');
    my $content = $res->decoded_content();

    my $scraper = scraper {
        process '//input[@name="authenticity_token"]', token     => '@value';
        process '//input[@name="humanness"]',          humanness => '@id';
        result qw/token humanness/;
    };
    my $result    = $scraper->scrape($content);
    my $humanness = $result->{humanness};
    $param->{authenticity_token} = uri_escape $result->{token};
    if($content =~m{\$\('#$humanness'\)\.get\(0\)\.value = '(.*?)';}){
        $param->{humanness}         = $1;
    }
    return $param
}


=item b<_parse>

scrape at the chat room's logs.

=cut

sub _parse {
    my $self = shift;
    my $html = shift;

    my $scraper = scraper {
        process '//div[@id="right"]/div', 'data' => scraper {
            process '//div[@class="timestamp"]',   'timestamp[]'   => 'TEXT';
            process '//span[@class="nickname"]',   'nickname[]'    => 'TEXT';
            process '//div[@class="decorated"]',   'description[]' => 'TEXT';
            process '//div[@class="permalink"]/a', 'permalink[]'   => '@href';
            process '//a[@class="speaker"]',       'speaker[]'     => '@href';
        };
        result 'data';
    };
    my $result = $scraper->scrape($html);
    my $data = [];
    for my $index (0..$#{$result->{nickname}}){
        my $row = {
            nickname    => $result->{nickname}->[$index],
            description => $result->{description}->[$index],
            timestamp   => $result->{timestamp}->[$index],
            id          => [split /message-/, $result->{permalink}->[$index]]->[1],
            speaker     => [split m{/}, $result->{speaker}->[$index]]->[1],
        };
        push @$data, $row;
    }
    return $data;
}

=back

=cut

1;

__END__

=head1 AUTHOR

Likkradyus E<lt>perl{at}li.que.jpE<gt>

=head1 SEE ALSO

L<http://lingr.com>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
