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

=pod

  {
    require HTTP::Headers;
    my $headers = HTTP::Headers->new;
    $headers->content_type('text/test2; charset=zxywv');
    $headers->content_type_charset('abcdefg');
    #$headers->header('Content-Type' => 'text/test; charset=abc');
    say 'HTTP::Headers::Fast -- ' . $headers->header('Content-Type');
    say 'HTTP::Headers::Fast -- ' . join('; ', $headers->content_type);
    say 'HTTP::Headers::Fast -- ' . $headers->content_type_charset;
    use Data::Dumper;
    #say Dumper { headers_fast => $headers };
  }

  # Content type and charset
  {
    my $response = Plack::Response->new;
    $response->content_type('text/test; charset=abc');
    $response->content_type_charset('abc');
    say "$response content_type                 -- " . $response->content_type;
    say "$response headers->content_type        -- " . $response->headers->content_type;
    say "$response headers->header->header(...) -- " . $response->headers->header('Content-Type');
    say Dumper { response => $response };
    my @vals = $response->content_type;
    say scalar @vals;
    say $_ for @vals;
    is(
      $response->content_type => 'text/test; charset=abc',
      'Set charset then content-type'
    );
  }

=cut

  # Charset then Content type
  {
    my $response = PlackX::Framework::Response->new;
    $response->charset('abc');
    $response->content_type('text/test');
    is_deeply(
      [$response->headers->content_type] => ['text/test', 'charset=abc'],
      'Set charset then content-type'
    );
  }

  # Content-type then charset
  {
    my $response = PlackX::Framework::Response->new;
    $response->content_type('text/test2');
    $response->charset('def');
    is_deeply(
      [$response->headers->content_type] => ['text/test2', 'charset=def'],
      'Set content-type then charset'
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
