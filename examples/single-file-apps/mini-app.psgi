package MiniApp {
  use PlackX::Framework;
  use MiniApp::Router;
  request '/' => sub {
    my ($request, $response) = @_;
    $response->print('Hello ' . ($request->param('name') || 'World!'));
    return $response;
  }
}

MiniApp->app;
