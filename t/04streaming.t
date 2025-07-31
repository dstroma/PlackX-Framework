#!perl
use v5.36;
use Test::More;

do_tests();
done_testing();

#######################################################################

sub do_tests {
  use Plack::Runner;
  use Plack::LWPish;
  use HTTP::Request;

  my @content = map {
    "Content-Line-$_:" . int(rand(10_000)) . "\n"
  } 0..5;

  ok(
    eval {
      package My::Test::App {
        use PlackX::Framework;
        use My::Test::App::Router;
        route '/streaming-test' => sub ($request, $response) {
          $response->print(shift @content);
          $response->print(shift @content);
          return $response->render_stream(sub {
            do { $response->print($_); sleep 1 } for @content;
            sleep 1;
            exit 0;
          });
        };
      }
      1;
    },
    'Make a streaming app'
  );

  ok(
    (My::Test::App->app and ref My::Test::App->app eq 'CODE'),
    'Test app is an app'
  );

  my $port = 40_000 + int(rand() * 20_000);
  my $fork = fork();
  die "Cannot fork! $!" unless defined $fork;

  my $http_response;
  if ($fork == 0) {
    # Child
    my $runner = Plack::Runner->new;
    $runner->parse_options('--port' => $port);
    $runner->run(My::Test::App->app);
  } else {
    # Parent
    sleep 1;
    my $ua  = Plack::LWPish->new;
    my $req = HTTP::Request->new(GET => "http://localhost:$port/streaming-test");
    $http_response = $ua->request($req);
  }

  is(
    $http_response->content => join('', @content),
    'Server response is correct content' . join('', @content)
  );
}
