#!perl
use v5.36;
use Class::Unload;
use Benchmark qw(cmpthese);

my $make_mojo = q|
  # Automatically enables "strict", "warnings", "utf8" and Perl 5.16 features
  package My::MojoApp {
    use Mojolicious::Lite -signatures;

    # Route with placeholder
    get '/' => sub ($c) {
      $c->render(html => 'Hello World!');
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
    app->start('psgi');
  }
|;

my $make_pxf = q|
  package My::PXFApp {
    use PlackX::Framework;
    use My::PXFApp::Router;

    route '/' => sub ($req, $resp) {
      $resp->print('Hello World!');
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
    My::PXFApp->app;
  }
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

cmpthese(100, {
  mojo => sub { do_in_fork(sub { eval $make_mojo; 1 }) },
   pxf => sub { do_in_fork(sub { eval $make_pxf ; 1 }) },
});

__END__

=pod

Results:

          Rate mojo  pxf
    mojo 3.76/s   -- -78%
    pxf  17.2/s 358%   --

Mojolicious::Lite app load time: 0.27s
PlackX::Framework app load time: 0.06s
