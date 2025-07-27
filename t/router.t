#!perl
use v5.36;

package My::Test::Controller {
  use Test::More;

  # Require
  require_ok('PlackX::Framework::Router');

  # Set up basic ap
  use PlackX::Framework;
  use My::Test::Controller::Router;
  our $somevar;

  # Global filters
  My::Test::Controller::Router->add_global_filter(before => sub {
    warn "I am a before filter.";
  });

  # Helpers
  sub match { My::Test::Controller::Router->engine->match(@_) }
  sub new_request { PlackX::Framework::Request->new(@_) }

  # Routes
  ok(eval q{
    filter 'before' => sub { $My::Test::Controller::somevar = $$; return; };

    route '/home' => sub { };
    route get => '/get-only' => sub { };
    route post => '/post-only' => sub { };
    route 'get|post|put' => '/getpostput' => sub {};
    route 'delete|post|put' => '/deletepostput' => sub {};
    route [qw(patch pick pluck)] => '/pverb' => sub {};

    base '/app';
    route '/article/:article' => sub { };
    1;
  }); warn $@ if $@;

  # Invalid
  ok(not eval q{
    no warnings;
    before_filter 'blah' => sub { };
    1;
  });

  # Invalid
  ok(not eval q{
    no warnings;
    get '/url' => sub { };
    1;
  });

  # Test routes and Filters
  # Bad route
  my $env = main::sample_env();
  my $match = match(new_request($env));
  ok(not $match);

  # Good Route
  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/home';
  $match = match(new_request($env));
  ok($match);

  # Test Filter
  ok($match->{prefilters}[0] and ref $match->{prefilters}[0]{action} eq 'CODE');
  ok(not $match->{prefilters}[0]{action}->());
  ok($somevar == $$);

  # Route with params
  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/app/article/255';
  $match = match(new_request($env));
  ok($match && $match->{'article'} eq '255');

  # Test route with request methods
  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/get-only';
  ok(match(new_request($env)));

  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/post-only';
  ok(not match(new_request($env)));

  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/delete-post-put';
  ok(not match(new_request($env)));

  $env->{REQUEST_METHOD} = 'POST';
  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/get-only';
  ok(not match(new_request($env)));

  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/post-only';
  ok(match(new_request($env)));

  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/deletepostput';
  ok(match(new_request($env)));

  $env->{REQUEST_METHOD} = 'DELETE';
  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/get-only';
  ok(not match(new_request($env)));

  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/post-only';
  ok(not match(new_request($env)));

  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/deletepostput';
  ok(match(new_request($env)));

  # Method call routes
  My::Test::Controller::Router->add_route('/class-method/:param', sub { });
  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/class-method/argument';
  $match = match(new_request($env));
  ok($match && $match->{'param'} eq 'argument');

  # Method call route with base
  My::Test::Controller::Router->add_route('/another-method/:param', sub { }, base => '/basic/');
  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/basic/another-method/debate';
  $match = match(new_request($env));
  ok($match && $match->{'param'} eq 'debate');

  # Method call with filter
  My::Test::Controller::Router->add_route('/class-filter', sub { }, filter => { before => sub { $$*2; } });
  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/class-filter';
  $match = match(new_request($env));
  ok($match && $match->{prefilters} && $match->{prefilters}[0]->() == $$*2);

  # Method call with after filter
  My::Test::Controller::Router->add_route('/class-filter', sub { }, filters => { after => [sub { $$*3; }] });
  $env->{PATH_INFO} = $env->{SCRIPT_NAME} = '/class-filter';
  $match = match(new_request($env));
  ok($match && $match->{postfilters} && $match->{postfilters}[0]->() == $$*3);


  done_testing();
}

sub sample_env ($method = 'GET') {
  return {
    REQUEST_METHOD    => uc $method,
    SERVER_PROTOCOL   => 'HTTP/1.1',
    SERVER_PORT       => 80,
    SERVER_NAME       => 'example.com',
    SCRIPT_NAME       => '/foo',
    REMOTE_ADDR       => '127.0.0.1',
    PATH_INFO         => '/foo',
    'psgi.version'    => [ 1, 0 ],
    'psgi.input'      => undef,
    'psgi.errors'     => undef,
    'psgi.url_scheme' => 'http',
  }
};
