use strict;
use warnings;
use Test::More;
use WWW::Lingr::Simple;

subtest "basic" => sub {

  my $w = WWW::Lingr::Simple->new;
  isa_ok $w, 'WWW::Lingr::Simple',    'create WWW::Lingr::Simple object';
  is $w->room, undef,                 'room is undef';
  $w->room('perl_jp');
  is $w->room, 'perl_jp',             'set room';
  my $data = $w->get;

  isa_ok $data, 'ARRAY',              'get array ref';
  my $line = $data->[0];
  isa_ok $line, 'HASH',               'row object is hash ref';

  ok $line->{nickname},               'has nickname';
  ok $line->{timestamp},              'has timestamp';
  ok $line->{description},             'has description';

};

done_testing();

