#!perl
use v5.36;
use Test::More;

{
  # Require
  require_ok('PlackX::Framework::Response');

  # Create
  {
    my $response = PlackX::Framework::Response->new;
    ok($response, 'Create response object');
    isa_ok($response, 'PlackX::Framework::Response');

    # Response properties
    ok(!$response->isa('Plack::Request' ));
    ok( $response->isa('Plack::Response'));

    # Stop and continue
    ok(ref $response->stop,  'Stop');
    ok(not($response->next), 'Next');
  }

  # Charset then Content type
  {
    my $response = PlackX::Framework::Response->new;
    is_deeply(
      [$response->content_type] => [''],
      'Empty content_type upon new()'
    );

    $response->charset('abc');
    is(
      $response->charset => 'abc',
      'Charset set successfully (before content_type)'
    );

    $response->content_type('text/test');
    is_deeply(
      [$response->headers->content_type] => ['text/test', 'charset=abc'],
      'Set charset then content-type'
    );

    # Set charset with content_type overrides earlier charset() call
    $response->content_type('text/test2; charset=def');
    is_deeply(
      [$response->headers->content_type] => ['text/test2', 'charset=def'],
      'Content_type is correct after setting content-type then charset'
    );
  }

  # Content-type then charset
  {
    my $response = PlackX::Framework::Response->new;
    $response->content_type('text/test3; charset=hij');
    $response->charset('klm');
    is(
      $response->charset => 'klm',
      'Charset set successfully (after content-type)'
    );
    is_deeply(
      [$response->headers->content_type] => ['text/test3', 'charset=klm'],
      'Content_type is correct after setting content-type then charset'
    );
  }

  # Print
  {
    my $response = PlackX::Framework::Response->new;
    $response->print('Line 1');
    $response->print('Line 2');
    my $body = join '', $response->body->@*;
    ok($body eq 'Line 1Line 2');
  }


}
done_testing();
