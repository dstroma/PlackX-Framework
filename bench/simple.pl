#!perl
use v5.36;
use Class::Unload;
use Benchmark qw(cmpthese);

$ENV{'PLACK_ENV'} = 'production'; # So we don't get a bunch of debug messages

my $make_mojo = q|
  # Automatically enables "strict", "warnings", "utf8" and Perl 5.16 features
  package My::MojoApp {
    use Mojolicious::Lite -signatures;

    # Route with placeholder
    get '/' => sub ($c) {
      $c->render(text => 'Hello World from Mojo!');
    };
    get '/aaa' => sub ($c) {
      $c->render(text => 'aaa');
    };
    get '/bbb' => sub ($c) {
      $c->render(text => 'bbb');
    };
    get '/ccc' => sub ($c) {
      $c->render(text => 'ccc');
    };
    get '/ddd' => sub ($c) {
      $c->render(text => 'ddd');
    };
    get '/eee' => sub ($c) {
      $c->render(text => 'eee');
    };
    get '/fff' => sub ($c) {
      $c->render(text => 'fff');
    };
    get '/:section/:page' => sub ($c) {
      $c->render(text => $c->param('eee'));
    };
    app->start('psgi');
  }
|;

my $make_pxf = q|
  package My::PXFApp {
    use PlackX::Framework;
    use My::PXFApp::Router;

    route '/' => sub ($req, $resp) {
      $resp->print('Hello World from PxF!!');
      return $resp;
    };
    route '/aaa' => sub ($req, $resp) {
      $resp->print('aaa');
      return $resp;
    };
    route '/bbb' => sub ($req, $resp) {
      $resp->print('bbb');
      return $resp;
    };
    route '/ccc' => sub ($req, $resp) {
      $resp->print('ccc');
      return $resp;
    };
    route '/ddd' => sub ($req, $resp) {
      $resp->print('ddd');
      return $resp;
    };
    route '/eee' => sub ($req, $resp) {
      $resp->print('eee');
      return $resp;
    };
    route '/fff' => sub ($req, $resp) {
      $resp->print('fff');
      return $resp;
    };
    route '/{section}/{page}' => sub ($req, $resp) {
      $resp->print($req->param('eee'));
      return $resp;
    };
    My::PXFApp->app;
  }
|;

my $make_dan2 = q|
  package My::Dan2App {
    use Dancer2;
    get '/'    => sub { 'Hello World from Dan2!' };
    get '/aaa' => sub { 'aaa'         };
    get '/bbb' => sub { 'bbb'         };
    get '/ccc' => sub { 'ccc'         };
    get '/ddd' => sub { 'ddd'         };
    get '/eee' => sub { 'eee'         };
    get '/fff' => sub { 'fff'         };
    get '/:section/:page' => sub { query_parameters->get('eee'); };
    My::Dan2App->to_app;
  };
|;

sub do_in_fork ($subref) {
  my $pid = fork;
  die if !defined $pid;
  if ($pid == 0) {
    $subref->();
    #say "Child is done.";
    exit 0;
  } else {
    #say "Parent is waiting...";
    waitpid($pid, 0);
    #say "Parent is done.";
  }
}

cmpthese(10, {
  mojo => sub { do_in_fork(sub { eval $make_mojo; 1 }) },
   pxf => sub { do_in_fork(sub { eval $make_pxf ; 1 }) },
  dan2 => sub { do_in_fork(sub { eval $make_dan2; 1 }) },
});

use Plack::Test;
use HTTP::Request::Common;
{
  my $app_mojo = eval $make_mojo;
  my $app_pxf  = eval $make_pxf;
  my $app_dan2 = eval $make_dan2;

  my $test_app = sub ($app) {
    test_psgi $app, sub {
        my $cb  = shift;
        $cb->(GET "/");
        $cb->(GET "/aaa");
        $cb->(GET "/bbb");
        $cb->(GET "/ccc");
        $cb->(GET "/ddd");
        $cb->(GET "/eee");
        $cb->(GET "/fff");
        $cb->(GET "/somepage/blah?qqq=111&bbb=222&ccc=333&ddd=444&eee=555&fff=666");
     };
  };

  # Warm up before main test
  cmpthese(5, {
    mojo => sub { $test_app->($app_mojo) },
    pxf  => sub { $test_app->($app_pxf ) },
    dan2 => sub { $test_app->($app_dan2) },
  });

  cmpthese(5000, {
    mojo => sub { $test_app->($app_mojo) },
    pxf  => sub { $test_app->($app_pxf ) },
    dan2 => sub { $test_app->($app_dan2) },
  });


}

__END__

=pod

=head1 RESULTS

=head2 Load Time Test:

           Rate dan2 mojo  pxf
    dan2 3.02/s   -- -14% -81%
    mojo 3.50/s  16%   -- -78%
    pxf  15.6/s 417% 346%   --

Load time per app:

    dan2 load time: 0.33s
    mojo load time: 0.29s
    pxf  load time: 0.07s

=head2 Request test:

          Rate dan2 mojo  pxf
    dan2 235/s   --  -2% -60%
    mojo 240/s   2%   -- -59%
    pxf  590/s 151% 146%   -

=cut
