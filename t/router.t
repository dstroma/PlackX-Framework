#!perl
use v5.36;
use Test::More;

do_tests();
done_testing();

# TODO
# test class-method syntax, multiple filters, global filters, more regexes

#######################################################################

sub do_tests {
  require_ok('PlackX::Framework::Router');

  # Make an app
  ok(
    eval {
      package My::Test::App {
        use PlackX::Framework;
        use My::Test::App::Router;
      }
      1;
    },
    'Create a new app, import routing'
  );

  # Check to see if the DSL was imported
  ok(
    ref \&My::Test::App::base eq 'CODE',
    'DSL "base" keyword imported'
  );

  ok(
    ref \&My::Test::App::filter eq 'CODE',
    'DSL "filter" keyword imported'
  );

  ok(
    ref \&My::Test::App::route eq 'CODE',
    'DSL "route" keyword imported'
  );

  # Set a URI base, add filters, and a route
  ok(
    eval {
      package My::Test::App {
        our $x = 0;

        # Route before base
        route '/no-base' => sub { };

        # Set a base for remainign routes
        base '/my-test-app';

        # Simple route, unfiltered
        route '/test1' => sub { $x = 3; };

        # Add some filters for remaining routes
        filter before => sub { $x = 1; return; };
        filter after  => sub { $x = 2; return; };

        # Route with param
        route '/test1/page/{some_param}' => sub { $x = 3.5; };

        # Route with method
        route get  => '/test1-method-get'  => sub { $x = 4; };
        route post => '/test1-method-post' => sub { $x = 5; };

        # Route with alternate methods
        route 'put|delete' => '/test1-put-or-delete' => sub { $x = 6; };

        # Route hashref test
        route {
          get => '/test1-hashref-get',
          put => '/test1-hashref-put',
        } => sub { $x = 7 };

        # Route arrayref test
        route ['/test1-aaa', '/test1-bbb'] => sub { $x = 8; };

      }
      1;
    },
    'Add a base, some filters, and some routes'
  );

  #######################
  # Test route matching #
  #######################
  my sub match {
    My::Test::App::Router->engine->match(@_)
  }

  ok(
    match(sample_request(get => '/no-base')),
    'Should match no-base'
  );

  is(
    match(sample_request(get => '/my-test-app/no-base')) => undef,
    'Path without base should not match path after base'
  );

  is(
    match(sample_request(get => '/')) => undef,
    'Should not match without base'
  );

  is(
    match(sample_request(get => '/test1')) => undef,
    'Should not match without base'
  );

  is(
    match(sample_request(get => '/test1/page/blah')) => undef,
    'Should not match without base'
  );

  ok(
    match(sample_request(get => '/my-test-app/test1')),
    'Basic match ok'
  );

  ok(
    match(sample_request(get => '/my-test-app/test1/page/whatever')),
    'Param match ok'
  );

  is(
    match(sample_request(get => '/my-test-app/test1/page/whatever'))->{some_param} => 'whatever',
    'Route param set successfully'
  );

  ok(
    match(sample_request(get => '/my-test-app/test1-method-get')),
    'Match with method get ok'
  );

  ok(
    match(sample_request(post => '/my-test-app/test1-method-post')),
    'Match with method post ok'
  );

  is(
    match(sample_request(post => '/my-test-app/test1-method-get')) => undef,
    'Get does not match post request'
  );

  is(
    match(sample_request(get => '/my-test-app/test1-method-post')) => undef,
    'Post does not match get request'
  );

  ok(
    match(sample_request(put => '/my-test-app/test1-put-or-delete')),
    'Match with method put|delete (put) ok'
  );

  ok(
    match(sample_request(delete => '/my-test-app/test1-put-or-delete')),
    'Match with method put|delete (delete) ok'
  );

  is(
    match(sample_request(get => '/my-test-app/test1-put-or-delete')) => undef,
    'Get request does not match put|delete'
  );

  is(
    match(sample_request(post => '/my-test-app/test1-put-or-delete')) => undef,
    'Post request does not match put|delete'
  );

  ok(
    match(sample_request(get => '/my-test-app/test1-hashref-get')),
    'Successful match hashref route (get)'
  );

  ok(
    match(sample_request(put => '/my-test-app/test1-hashref-put')),
    'Successful match hashref route (put)'
  );

  is_deeply(
    match(sample_request(get => '/my-test-app/test1-hashref-get')),
    match(sample_request(put => '/my-test-app/test1-hashref-put')),
    'Same route'
  );

  is(
    match(sample_request(get => '/my-test-app/test1-hashref-put')) => undef,
    'Should not match'
  );

  is(
    match(sample_request(put => '/my-test-app/test1-hashref-get')) => undef,
    'Should not match'
  );

  ok(
    match(sample_request(get => '/my-test-app/test1-aaa')),
    'Successful match arrayref route'
  );

  ok(
    match(sample_request(get => '/my-test-app/test1-bbb')),
    'Successful match arrayref route'
  );

  is(
    match(sample_request(get => '/my-test-app/test1-ccc')) => undef,
    'Should not match'
  );

  is_deeply(
    match(sample_request(get => '/my-test-app/test1-aaa')),
    match(sample_request(get => '/my-test-app/test1-bbb')),
    'Arrayref routes are the same route'
  );

  #######################
  # Test filters        #
  #######################
  {
    my $match = match(sample_request(get => '/my-test-app/test1'));
    is(
      $match->{prefilters} => undef,
      'First route should have no pre filters'
    );
    is(
      $match->{postfilters} => undef,
      'First route should have no post filters'
    );
  }
  {
    my $match = match(sample_request(get => '/my-test-app/test1/page/whatever'));
    is(
      ref $match->{prefilters} => 'ARRAY',
      'Second route has pre filters'
    );
    is(
      ref $match->{prefilters} => 'ARRAY',
      'Second route has post filters'
    );

    my $prefilter = $match->{prefilters}[0];
    $prefilter = (ref $prefilter eq 'CODE') ? $prefilter : $prefilter->{action};
    $prefilter->();

    is(
      $My::Test::App::x => 1,
      'Prefilter set a variable'
    );

    my $postfilter = $match->{postfilters}[0];
    $postfilter = (ref $postfilter eq 'CODE') ? $postfilter : $postfilter->{action};
    $postfilter->();

    is(
      $My::Test::App::x => 2,
      'Prefilter set a variable'
    );
  }
  {
    my $match = match(sample_request(get => '/my-test-app/test1-aaa'));
    is(
      ref $match->{prefilters} => 'ARRAY',
      'Last route has pre filters'
    );
    is(
      ref $match->{prefilters} => 'ARRAY',
      'Last route has post filters'
    );
  }
}

#######################################################################
# Helpers

sub sample_request {
  return PlackX::Framework::Request->new(sample_env(@_));
}

sub sample_env ($method = 'GET', $uri = '/') {
  return {
    REQUEST_METHOD    => uc $method,
    SERVER_PROTOCOL   => 'HTTP/1.1',
    SERVER_PORT       => 80,
    SERVER_NAME       => 'example.com',
    SCRIPT_NAME       => $uri,
    REMOTE_ADDR       => '127.0.0.1',
    PATH_INFO         => $uri,
    'psgi.version'    => [ 1, 0 ],
    'psgi.input'      => undef,
    'psgi.errors'     => undef,
    'psgi.url_scheme' => 'http',
  }
}
