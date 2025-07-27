use v5.36;
package PlackX::Framework::Router::Engine {
  use parent 'Router::Boom';

  # We use a Hybrid Singleton (one instance per inherited class)
  my %instances;
  sub instance ($class) { $instances{$class} ||= $class->new; }

  sub match ($self, $request) {
    # Hack to make Router::Boom match against the HTTP request method
    my $destination = '/['.$request->method.']' . $request->destination;
    my @match = $self->SUPER::match($destination);
    return undef unless @match and @match == 2;

    # Consolidate the match info
    my ($destin, $captures) = @match;
    my %matchinfo = (%$destin, %$captures);
    delete $matchinfo{PXF_REQUEST_METHOD};

    # Add global filters
    for my $filter_type (qw/prefilters postfilters/) {
      if (my $filters = $self->match_global_filters($filter_type, $request)) {
        $matchinfo{$filter_type} ||= [];
        # global filters should be before route-specific ones
        unshift @{$matchinfo{$filter_type}}, @$filters;
      }
    }

    # Return match data as hashref
    return bless \%matchinfo, 'PlackX::Framework::Router::Engine::Match';
  }

  sub match_global_filters ($self, $kind, $request) {
    return unless defined $self->{"global_$kind"};
    my $matches = [];
    foreach my $filter ($self->{"global_$kind"}->@*) {
      my $pattern = $filter->{'pattern'};
      push @$matches, $filter->{action}
        if (!defined $pattern)
        or (ref $pattern eq 'SCALAR' and $request->destination eq $$pattern)
        or (ref $pattern eq 'Regexp' and $request->destination =~ $pattern)
        or (substr($request->destination, 0, length $pattern) eq $pattern);
    }
    return $matches;
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

  sub add_global_filter ($self, %params) {
    my $when    = delete $params{'when'};
    my $pattern = delete $params{'pattern'};
    my $action  = delete $params{'action'};
    die q{Usage: add_global_filter(when => 'before'|'after', ...)}
      unless $when eq 'before' or $when eq 'after';

    my $prefix = $when eq 'before' ? 'pre' : 'post';
    my $hkey   = 'global_' . $prefix . 'filters';
    $self->{$hkey} ||= [];
    push @{$self->{$hkey}}, { pattern => $pattern, action => $action };
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
        $method = '/[{PXF_REQUEST_METHOD:' . uc $method . '}]';
      } else {
        $method = '/[' . uc $method . ']';
      }
    }
    $method = '/[:PXF_REQUEST_METHOD]' unless $method;
    $path   = $method . $path;
    return $path;
  }

  sub path_with_base_and_method ($path, $base, $method = undef) {
    $path = path_with_base($path, $base);
    $path = path_with_method($path, $method);
    return $path;
  }
}

package PlackX::Framework::Router::Engine::Match {
  sub prefilters  ($self) { }
  sub postfilters ($self) { }
}

1;
