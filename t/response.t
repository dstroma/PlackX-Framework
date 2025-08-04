#!perl
use v5.36;
use Test::More;

{
  # Require
  require_ok('PlackX::Framework::Response');

  # Create
  my $response = PlackX::Framework::Response->new;
  ok($response, 'Create response object');
  isa_ok($response, 'PlackX::Framework::Response');

  # Response properties
  ok(!$response->isa('Plack::Request' ));
  ok( $response->isa('Plack::Response'));

  # Stop and continue
  ok(ref $response->stop,  'Stop');
  ok(not($response->next), 'Next');

  # Print
  $response->print('Line 1');
  $response->print('Line 2');
  my $body = join '', $response->body->@*;
  ok($body eq 'Line 1Line 2');

}
done_testing();
