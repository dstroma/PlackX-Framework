#!perl
use v5.36;
use Test::More;

package MyExample::Request {
  use parent 'PlackX::Framework::Request';
  sub app_namespace { 'MyExample' }
}

{
  # Require
  require_ok('PlackX::Framework::Request');

  # Create object
  my $request = MyExample::Request->new(sample_env());
  ok($request, 'Create request object');
  isa_ok($request, 'PlackX::Framework::Request');

  # Request properties
  ok( $request->isa('Plack::Request' ));
  ok(!$request->isa('Plack::Response'));

  ok($request->is_get);
  ok(!$request->is_post);
  ok(!$request->is_put);
  ok(!$request->is_delete);
  ok(!$request->is_ajax);

  # Stash
  my $stash = { boo => 'who' };
  $request->stash($stash);
  ok($request->stash->{boo} eq 'who');

  # Routes
  ok($request->destination eq $request->path_info);
  $request->reroute('/new');
  ok($request->destination eq '/new');

  # Namespace
  ok($request->app_namespace eq 'MyExample');

  # Flash
  ok(substr($request->flash_cookie_name, 0, 5) eq 'flash');
  ok(8 < length $request->flash_cookie_name < 64);

  # Route Params
  $request->route_parameters({ user_id => '8', page => 'paper' });
  ok($request->route_param('user_id') eq '8');
  ok($request->route_param('page') eq 'paper');

  # Params
  ok(my $food = $request->param('food') eq 'pizza');
  ok(my $drink = $request->param('drink') =~ m/^(beer|pepsi|wine|water)$/);
  my @drinks = $request->cgi_param('drink');
  ok(@drinks == 4);
  my @sdrinks = $request->param('drink');
  ok(@sdrinks == 1);

  # Todo - flash cookie test

}
done_testing();

####################################################

sub sample_env {
  return {
    REQUEST_METHOD    => 'GET',
    SERVER_PROTOCOL   => 'HTTP/1.1',
    SERVER_PORT       => 80,
    SERVER_NAME       => 'example.com',
    SCRIPT_NAME       => '/foo',
    REMOTE_ADDR       => '127.0.0.1',
    PATH_INFO         => '/foo',
    HTTP_COOKIE       => 'NOT_IMPLEMENTED=NOT_IMPLEMENTED',
    QUERY_STRING      => 'food=pizza&drink=beer&drink=pepsi&drink=wine&drink=water',
    'psgi.version'    => [ 1, 0 ],
    'psgi.input'      => undef,
    'psgi.errors'     => undef,
    'psgi.url_scheme' => 'http',
  }
};
