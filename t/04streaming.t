#!perl
use v5.36;
use Test::More;

do_tests();
done_testing();

#######################################################################

sub do_tests {
  use Plack::LWPish;
  use HTTP::Request;
  use constant BODY_LINES => 5;

  my @content = map { "Content-Line-$_:" . int(rand(10_000)) . "\n" } 1..BODY_LINES;

  ok(
    eval {
      package My::Test::App {
        use PlackX::Framework;
        use My::Test::App::Router;
        route '/streaming-test' => sub ($request, $response) {
          die "Server does not support streaming"
            unless $request->env->{'psgi.streaming'};
          $response->print(shift @content);
          $response->print(shift @content);
          return $response->render_stream(sub {
            do { $response->print($_); sleep 1 } for @content;
            sleep 1;
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
  my $server = run_server(port => $port, app => My::Test::App->app);

  sleep 1;
  my $data = run_client(path => '/streaming-test', %$server);
  stop_server($server);

  my @body_data = grep { $_->{line} =~ m/^Content-Line/ } @$data;
  my $body_text = join('', map { $_->{line} } @body_data);
  is(
    $body_text => join('', @content),
    'Server response is correct content'
  );

  my $t_2 = $body_data[-1]->{time};
  my $t_1 = $body_data[-2]->{time};
  my $elapsed = $t_2 - $t_1;
  ok(
    ($elapsed > 0.8 and $elapsed < 1.2),
    "Last body content lines received 1s +/- 0.2s apart (actual: $elapsed)"
  );
}

sub run_server (%options) {
  my $host = $options{host} || 'localhost';
  my $port = $options{port} || 50_000;
  my $app  = $options{app}  || $options{psgi} || './app.psgi';

  my $fork = fork();
  die "Cannot fork: $!" if !defined $fork;

  if ($fork == 0) {
    # Child
    require Plack::Runner;
    my $runner = Plack::Runner->new;
    $runner->parse_options('--port' => $port, '--host' => $host);
    $runner->run($app);
  } else {
    # Parent
    return { pid => $fork, host => $host, port => $port };
  }
}

sub stop_server ($server) {
  kill 9, $server->{'pid'};
}

sub run_client (%options) {
  require IO::Socket::INET;
  require Time::HiRes;

  my $socket = IO::Socket::INET->new(
      PeerAddr => $options{host},
      PeerPort => $options{port},
      Proto    => 'tcp',
  ) or die "Could not connect to server - $!";

  # Send HTTP request manually
  print $socket "GET $options{path} HTTP/1.0\r\n";
  print $socket "Connection: close\r\n";
  print $socket "\r\n";

  # Read and save the response and time of each line
  my @received_data = ();
  push @received_data, { line => $_, time => Time::HiRes::time() } while <$socket>;

  # Close the connection
  close($socket);

  return \@received_data;
}
