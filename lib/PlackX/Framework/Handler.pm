use v5.36;
package PlackX::Framework::Handler {
  use Scalar::Util qw(blessed);
  use Module::Loaded qw(is_loaded);
  use HTTP::Status qw(status_message);

  # Overridable options
  my %globals;
  my $streaming_support;
  sub use_global_request_response    { } # Override in subclass to turn on
  sub global_request        ($class) { $globals{$class->app_namespace}->[0]            }
  sub global_response       ($class) { $globals{$class->app_namespace}->[1]            }
  sub error_response ($class, $code) { [$code, [], [status_message($code)." ($code)"]] }

  # Public class methods
  sub to_app ($class, %options)  {
    my $serve_static_files = delete $options{'serve_static_files'};
    my $static_docroot     = delete $options{'static_docroot'};
    die "Unknown options: " . join(', ', keys %options) if %options;

    return sub ($env) { psgi_response($class->handle_request($env)) }
      unless $serve_static_files;

    require Plack::App::File;
    my $file_app = Plack::App::File->new(root => $static_docroot)->to_app;
    return sub ($env) {
      my $app_response  = psgi_response($class->handle_request($env));
      return $app_response if ref $app_response and $app_response->[0] != 404;
      my $file_response = psgi_response($file_app->($env));
      return $file_response;
    };
  }

  sub handle_request ($class, $env_or_req, $maybe_resp = undef) {
    my $app_namespace  = $class->app_namespace;

    # Get or create request and response objects
    my $env      = $class->env_or_req_to_env($env_or_req);
    my $request  = $class->env_or_req_to_req($env_or_req);
    my $response = $maybe_resp || ($app_namespace . '::Response')->new(200);

    # Maybe set globals
    $streaming_support = $env->{'psgi.streaming'} ? !!1 : !!0
      if !defined $streaming_support;

    $globals{$app_namespace} = [$request, $response]
      if $class->use_global_request_response;

    # Set up stash
    my $stash = ($request->stash or $response->stash or {});
    $request->stash($stash);
    $response->stash($stash);

    # Maybe set up Templating, if loaded
    if (is_loaded($app_namespace . '::Template')) {
      eval {
        my $template = ($app_namespace . '::Template')->new($response);
        $template->set(STASH => $stash, REQUEST => $request, RESPONSE => $response);
        $response->template($template);
      } or do {
        warn "$app_namespace\::Template module loaded, but unable to set up template: $@"
        .    "  (Hint: Did you use/import from it or set up templating manually?)\n";
      };
    }

    # Clear flash if set, set response defaults, and route request
    $response->flash(undef) if $request->flash;
    $response->content_type('text/html');
    return $class->route_request($request, $response);
  }

  sub route_request ($class, $request, $response) {
    my $result = check_request_prefix($class->app_namespace, $request);
    return $result if $result;

    my $rt_engine = ($class->app_namespace . '::Router::Engine')->instance;
    if (my $match = $rt_engine->match($request)) {
      $request->route_base($match->{base}) if defined $match->{base};
      $request->route_parameters($match->{route_parameters});

      # Execute global and route-specific prefilters
      if (my $filterset = $match->{prefilters}) {
        my $ret = execute_filters($filterset, $request, $response);
        return $ret if $ret and is_valid_response($ret);
      }

      # Execute main action
      my $result = $match->{action}->($request, $response);
      unless ($result and ref $result) {
        warn "PlackX::Framework - Invalid result '$result'\n";
        return $class->error_response(500);
      }

      # Check if the result is actually another request object
      return $class->handle_request($result) if $result->isa('Plack::Request');
      return $class->error_response unless $result->isa('Plack::Response');
      $response = $result;

      # Execute postfilters
      if (my $filterset = $match->{postfilters}) {
        my $ret = execute_filters($filterset, $request, $response);
        return $ret if $ret and is_valid_response($ret);
      }

      # Clean up (does server support cleanup handlers? Add to list or else execute now)
      if ($response->cleanup_callbacks and scalar $response->cleanup_callbacks->@* > 0) {
        if ($request->env->{'psgix.cleanup'}) {
          push $request->env->{'psgix.cleanup.handlers'}->@*, $response->cleanup_callbacks->@*;
        } else {
          $_->($request->env) for $response->cleanup_callbacks->@*;
        }
      }

      return $response if is_valid_response($response);
    }

    return $class->error_response(404);
  }

  # Helpers ###################################################################

  sub check_request_prefix ($class, $request) {
    if ($class->can('uri_prefix') and my $prefix = $class->uri_prefix) {
      $prefix = "/$prefix" if substr($prefix,0,1) ne '/';
      if (substr($request->destination, 0, length $prefix) eq $prefix) {
        $request->{destination}    = substr($request->destination, length $prefix);
        $request->{removed_prefix} = $prefix;
        return;
      }
      return not_found_response();
    }
    return;
  }

  sub execute_filters ($filters, $request, $response) {
    return unless $filters and ref $filters eq 'ARRAY';
    foreach my $filter (@$filters) {
      $filter = { action => $filter, params => [] } if ref $filter eq 'CODE';
      my $response = $filter->{action}->($request, $response, @{$filter->{params}});
      return $response if $response and is_valid_response($response);
    }
    return;
  }

  sub is_valid_response {
    my $response = pop;
    return !!0 unless defined $response and ref $response;
    return !!1 if ref $response eq 'ARRAY' and (@$response == 3 or @$response == 2);
    return !!1 if blessed $response and $response->can('finalize');
    return !!0;
  }

  sub psgi_response ($resp) {
    return $resp
      if !blessed $resp;

    return $resp->finalize
      if not $resp->can('stream') or not $resp->stream;

    return sub ($PSGI_responder) {
      my $PSGI_writer = $PSGI_responder->($resp->finalize_s);
      $resp->stream_writer($PSGI_writer);
      $resp->stream->();
      $PSGI_writer->close;
    } if $streaming_support;

    # Simulate streaming
    # "do" to make it look consistent with the above stanzas
    return do {
      $resp->stream->();
      $resp->stream(undef);
      $resp->finalize;
    };
  }

  sub env_or_req_to_req ($class, $env_or_req) {
    if (ref $env_or_req and ref $env_or_req eq 'HASH') {
      return ($class->app_namespace . '::Request')->new($env_or_req);
    } elsif (blessed $env_or_req and $env_or_req->isa('PlackX::Framework::Request')) {
      return $env_or_req;
    }
    die 'Neither a PSGI-type HASH reference nor a PlackX::Framework::Request object.';
  }

  sub env_or_req_to_env ($class, $env_or_req) {
    if (ref $env_or_req and ref $env_or_req eq 'HASH') {
      return $env_or_req;
    } elsif (blessed $env_or_req and $env_or_req->isa('PlackX::Framework::Request')) {
      return $env_or_req->env;
    }
    die 'Neither a PSGI-type HASH reference nor a PlackX::Framework::Request object.';
  }
}

1;
