use v5.36;
package PlackX::Framework::Router::Engine {
  use parent 'Router::Boom';

  # We use a Hybrid Singleton (one instance per inherited class)
  my %instances;
  sub instance ($class) { $instances{$class} ||= $class->new; }

  sub match ($self, $request) {
    my @match = $self->SUPER::match('/['.$request->method.']' . $request->destination);

    if (@match and @match == 2) {
      my ($destin, $captures) = @match;
      my %matchinfo = (%$destin, %$captures);
      delete $matchinfo{REQUEST_METHOD};
      return bless \%matchinfo, 'PlackX::Framework::Router::Match';
    }
    return undef;
  }

  sub add_route ($router, %params) {
    my $route   = delete $params{routespec};
    my $base    = delete $params{base};
    my $path    = $route;

    if (ref $route eq 'HASH') {
      foreach my $key (keys %$route) {
        $path = $route->{$key};
        if (ref $path eq 'ARRAY') {
          my @paths = @$path;
          foreach $path (@paths) {
            $router->add(path_with_base_and_method($path, $base, uc $key), \%params);
          }
        } else {
          $router->add(path_with_base_and_method($path, $base, uc $key), \%params);
        }
      }
    } elsif (ref $route eq 'ARRAY') {
      foreach $path (@$route) {
        $router->add(path_with_base_and_method($path, $base), \%params);
      }
    } else {
      $router->add(path_with_base_and_method($path, $base), \%params);
    }
  }

  sub path_with_base ($path, $base) {
    return $path unless $base and length $base;
    $path = '/' . $path if substr($path, 0, 1) ne '/';
    return $base . $path;
  }

  sub path_with_method ($path, $method = undef) {
    # $method can be undef, http verb, or verbs separated with pipe (e.g. 'get|post')
    if ($method) {
      if ($method =~ m/|/) {
        $method = '/[{REQUEST_METHOD:' . uc $method . '}]';
      } else {
        $method = '/[' . uc $method . ']';
      }
    }
    $method = '/[:REQUEST_METHOD]' unless $method;
    $path   = $method . $path;
    return $path;
  }

  sub path_with_base_and_method ($path, $base, $method = undef) {
    $path = path_with_base($path, $base);
    $path = path_with_method($path, $method);
    return $path;
  }
}

1;
