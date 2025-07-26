#!perl
use v5.36;
use Test::More;

do_tests();
done_testing();

#######################################################################

sub do_tests {

  # use() PlackX::Framework
  ok(
    eval qq{
      package My::Test::App1 {
        use PlackX::Framework;
      }
      1;
    },
    'Create an empty app called $test_app_namespace'
  );

  # See if required subclasses are automatically created
  foreach my $auto_class (qw(Handler Request Response Router Router::Engine)) {
    ok(
      "My::Test::App1::$auto_class"->isa('PlackX::Framework::'.$auto_class),
      "$auto_class is automatically created and is subclass of respective PXF class"
    );

    ok(
      "My::Test::App1::$auto_class"->can('app_namespace'),
      "$auto_class has an app_namespace method"
    );

    is(
      "My::Test::App1::$auto_class"->app_namespace => 'My::Test::App1',
       "$auto_class app_namespace method returns correct name"
    );

  }

}

=pod


	ok(
		eval qq{
			package $test_app_namespace {
				use PlackX::Framework;
				use $test_app_namespace\::Router;
				route '/' => sub {
                    my (\$request, \$response) = \@_;
					\$response->print("<html>test from process $$</html>");
                    return \$response;
				};
				route '/empty' => sub { };
			}
			1;
		},
		"Create a controller with a route to /" . ($@ ? "\n$@" : ""),
	);
}

sub test5 {
	# Make sure ->to_app returns a code reference
	my $code = ($test_app_namespace . '::Handler')->to_app;
	ok(
		ref $code eq 'CODE',
		"$test_app_namespace\::App->to_app returns a coderef"
	);
}

sub test6 {
	# Get a response from /
	my $code = ($test_app_namespace . '::Handler')->to_app;
	my $resp = $code->(test_env());
	ok(
		(ref $resp eq 'ARRAY' and $resp->[2][0] eq "<html>test from process $$</html>"),
		"Response is ARRAYREF and body matches expected body"
	);
}

###############################################################################
sub test_env {
	return {
		'HTTP_ACCEPT' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
		'HTTP_SEC_CH_UA_MOBILE' => '?0',
		'HTTP_CONNECTION' => 'keep-alive',
		'psgi.version' => [1, 1],
		'REQUEST_METHOD' => 'GET',
		#'psgi.input' => \*{'HTTP::Server::PSGI::$input'},
		'psgi.run_once' => '',
		'HTTP_USER_AGENT' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.63 Safari/537.36',
		'HTTP_SEC_FETCH_DEST' => 'document',
		'SCRIPT_NAME' => '',
		'HTTP_SEC_CH_UA' => '"Google Chrome";v="93", " Not;A Brand";v="99", "Chromium";v="93"',
		'HTTP_ACCEPT_LANGUAGE' => 'en-US,en;q=0.9',
		'HTTP_SEC_FETCH_USER' => '?1',
		'psgi.errors' => *::STDERR,
		'SERVER_PROTOCOL' => 'HTTP/1.1',
		'HTTP_SEC_FETCH_SITE' => 'none',
		'PATH_INFO' => '/',
		'psgi.streaming' => 1,
		'psgi.url_scheme' => 'http',
		'HTTP_DNT' => '1',
		'psgi.nonblocking' => '',
		'HTTP_CACHE_CONTROL' => 'max-age=0',
		'HTTP_ACCEPT_ENCODING' => 'gzip, deflate, br',
		'REMOTE_ADDR' => '127.0.0.1',
		'psgi.multithread' => '',
		'psgix.harakiri' => 1,
		'HTTP_HOST' => 'localhost:5000',
		'SERVER_NAME' => 0,
		'REMOTE_PORT' => 62037,
		'SERVER_PORT' => 5000,
		'psgi.multiprocess' => '',
		'QUERY_STRING' => '',
		'psgix.input.buffered' => 1,
		'HTTP_UPGRADE_INSECURE_REQUESTS' => '1',
		'HTTP_SEC_CH_UA_PLATFORM' => '"macOS"',
		'HTTP_SEC_FETCH_MODE' => 'navigate',
		'REQUEST_URI' => '/'
	};
}
