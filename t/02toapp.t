#!perl
use v5.36;
use Test::More;

do_tests();
done_testing();

#######################################################################

sub do_tests {

  # use() PlackX::Framework
  eval q{
    package My::Test::App2 {
      use PlackX::Framework;
      use My::Test::App2::Router;
      # TODO: Currently, an app with no routes breaks!
      # Add a default route or warn if no routes?
      request '/' => sub ($request, $response) {
        $response->print('Hello world!');
        $response;
      };
    }
    1;
  } or die "Problem setting up test: $@";

  ok(My::Test::App2->can('app'),
    'app() class method generated'
  );

  ok(My::Test::App2::Handler->can('to_app'),
    'Handler::to_app method generated'
  );

  my $app = My::Test::App2::Handler->to_app;
  ok(
    (ref $app and ref $app eq 'CODE'),
    'Handler->to_app returns a coderef'
  );

  my $app2 = My::Test::App2->app;
  ok(
    (ref $app2 and ref $app2 eq 'CODE'),
    'AppNamespace->app returns a coderef'
  );

  my $result = $app->(test_env());
  ok(
    (ref $result and ref $result eq 'ARRAY'),
    'Handler->to_app->() returns arrayref'
  );

  ok(
    ($result->[0] == 200 and $result->[2][0] eq 'Hello world!'),
    'Handler->to_app->() response is as expected'
  );

  my $result2 = $app2->(test_env());
  is_deeply(
    $result, $result2,
    'Calling Handler->to_app->() and App->app->() gives same result'
  );

  # use() PlackX::Framework with all optional modules
  eval q{
    package My::Test::App2b {
      use PlackX::Framework qw(:config);
      use My::Test::App2b::Router;
      use My::Test::App2b::Config './t/config.pl';
      my $config = config();
      # TODO: Currently, an app with no routes breaks!
      # Add a default route or warn if no routes?
      request '/' => sub ($request, $response) {
        $response->print('Hello world!');
        $response;
      };
    }
    1;
  } or die "Problem setting up test with config: $@";

  ok(
    My::Test::App2b->config,
    'New app has a config() method'
  );

  is(
    ref My::Test::App2b->config => 'HASH',
    'Config method returns expected data structure'
  );

  is(
    My::Test::App2b->config->{key2} => 'value2',
    'Config file contains expected data'
  );
}

#######################################################################

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
    'QUERY_STRING' => '',
    'HTTP_ACCEPT' => 'text/html,text/plain',
    'REQUEST_METHOD' => 'GET',
    'HTTP_USER_AGENT' => 'Mock',
    'HTTP_SEC_FETCH_DEST' => 'document',
    'SCRIPT_NAME' => '',
    'HTTP_SEC_CH_UA' => '"Google Chrome";v="93", " Not;A Brand";v="99", "Chromium";v="93"',
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
    'HTTP_SEC_CH_UA_PLATFORM' => '"macOS"',
    'HTTP_SEC_FETCH_MODE' => 'navigate',
    'REQUEST_URI' => '/'
  };
}
