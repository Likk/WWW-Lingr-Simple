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

=item B<ROOM_URL>

chat room pattern.

=back

=cut

our $VERSION = '1.00';
our $BASE_URL = q{http://lingr.com/};
our $ROOM_URL = q{room/__NAME__/archives};

=head1 CONSTRUCTOR AND STARTUP

=head2 new

Creates and returns a new WWW::Lingr::Simple object.

  WWW::Lingr::Simple->new(
        room => q{room_name},
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
    $self->{__mech} ||= WWW::Mechanize->new;
}

=head1 METHODS

=head2 get

get logs at the chat room.

=cut

sub get {
    my $self = shift;
    my $room = $self->room;
    my $room_url = $ROOM_URL;
    $room_url =~ s{__NAME__}{$room};
    my $res = $self->mech->get($BASE_URL . $room_url);

    $self->_parse($res->decoded_content());
}

=head1 PRIVATE METHODS

=over

=item b<_parse>

scrape at the chat room's logs.

=cut

sub _parse {
    my $self = shift;
    my $html = shift;

    my $scraper = scraper {
            process '//div[@id="right"]/div', 'data' => scraper {
                process '//div[@class="timestamp"]', 'timestamp[]'   => 'TEXT';
                process '//span[@class="nickname"]', 'nickname[]'    => 'TEXT';
                process '//div[@class="decorated"]', 'description[]' => 'TEXT';
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
