#!perl
use v5.36;
use Test::More;

do_tests();
done_testing();

#######################################################################

sub do_tests {
  my $app = do './examples/single-file-apps/mini-app.psgi';

  ok(
    $app,
    'mini-app.psgi ok'
  );

  is(
    ref $app => 'CODE',
    'mini-app.psgi returns coderef'
  );

  my $test_env = test_env();
  my $response = $app->($test_env);

  ok(
    (ref $response eq 'ARRAY' and scalar @$response == 3),
    'app execution returns PSGI response arrayref'
  );
  is(
    $response->[0] => 200,
    'response status correct'
  );

  is_deeply(
    $response->[1] => ['Content-Type', 'text/html'],
    'response content-type correct'
  );

  ok(
    (ref $response->[2] and $response->[2][0] eq 'Hello Larry Wall'),
    'response body is correct'
  );
}

###############################################################################
sub test_env {
  return {
    'psgi.version' => [1, 1],
    'psgi.errors' => *::STDERR,
    'psgi.multiprocess' => '',
    'psgi.multithread' => '',
    'psgi.nonblocking' => '',
    'psgi.run_once' => '',
    'psgi.streaming' => 0,
    'psgi.url_scheme' => 'http',
    'psgix.harakiri' => 1,
    'psgix.input.buffered' => 1,
    'QUERY_STRING' => 'name=Larry%20Wall',
    'HTTP_ACCEPT' => 'text/html,text/plain',
    'REQUEST_METHOD' => 'GET',
    'HTTP_USER_AGENT' => 'Mock',
    'HTTP_SEC_FETCH_DEST' => 'document',
    'SCRIPT_NAME' => '',
    'HTTP_ACCEPT_LANGUAGE' => 'en-US,en;q=0.9',
    'HTTP_SEC_FETCH_USER' => '?1',
    'SERVER_PROTOCOL' => 'HTTP/1.1',
    'HTTP_SEC_FETCH_SITE' => 'none',
    'PATH_INFO' => '/',
    'HTTP_DNT' => '1',
    'HTTP_CACHE_CONTROL' => 'max-age=0',
    'HTTP_ACCEPT_ENCODING' => 'gzip, deflate, br',
    'REMOTE_ADDR' => '127.0.0.1',
    'HTTP_HOST' => 'localhost:5000',
    'SERVER_NAME' => 0,
    'REMOTE_PORT' => 62037,
    'SERVER_PORT' => 5000,
    'HTTP_UPGRADE_INSECURE_REQUESTS' => '1',
    'HTTP_SEC_FETCH_MODE' => 'navigate',
    'REQUEST_URI' => '/'
  };
}
