use v5.36;
package MyApp::Controllers {
  use MyApp::Router;
  use Time::HiRes ();

  base '/app';

  route ['', '/'] => sub ($request, $response) {
    $response->template->set(page_name => 'Home');
    return $response->render_template('index.html');
  };

  route get => '/feedback' => sub ($request, $response) {
    $response->template->set(page_name => 'Form');
    return $response->render_template('feedback.html');
  };

  route post => '/feedback' => sub ($request, $response) {
    $response->template->set(
      page_name         => 'Thank You',
      user_lucky_number => length($request->param('comments')),
    );
    return $response->render_template('feedback-thanks.html');
    return $response;
  };

  ### Secret Area #####################################################

  filter before => sub ($request, $response) {
    $response->status(403);
    return $response;
  };

  route '/admin' => sub ($request, $response) {
    $response->print('You should not be here! This is impossible!');
    return;
  }

}

1;
