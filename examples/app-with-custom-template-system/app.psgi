#!perl
use v5.36;

package Example::TemplateEngine {
  sub new       ($class)      { bless {}, $class           }
  sub error     ($self)       { $self->{err}               }
  sub set_error ($self, $msg) { $self->{err} = $msg; undef }

  # We implement a partially TT-compatible process() method, which in this case
  # takes a file name, a params hash, and an object with a print() method.
  # Our very simple template language replaces %%%var%%% with the value of var
  # This module does not HAVE to have a TT-compatible interface, but if not
  # will require more work to integrate.
  sub process ($self, $file, $params, $printer) {
    $file = "./percent-templates/$file.html";
    if (open(my $fh, '<', $file)) {
      while (my $line = <$fh>) {
        while (my ($varname) = $line =~ m/%%%(\w+)%%%/) {
          my $value = $params->{$varname} // '';
          $line =~ s/%%%\w+%%%/$value/;
        }
        $printer->print($line);
      }
      close $fh;
      return $self;
    }
    return $self->set_error("Cannot open template $file, $!");
  }
}

package MyApp {
  # Use PXF and enable optional template feature (or use :all)
  use PlackX::Framework qw(:template);

  # Set up templating
  use MyApp::Template qw(:manual);
  MyApp::Template->set_engine(Example::TemplateEngine->new);

  # Import routing
  use MyApp::Router;

  # Add routes
  request ['/', '/{page}'] => sub ($request, $response) {
    $response->template->set(
      page    => $request->route_param('page') || 'index',
      somevar => $request->param('somevar'),
      pid     => $$,
    );
    return $response->template->render('main');
  };
}

# Return app coderef
MyApp->app;
