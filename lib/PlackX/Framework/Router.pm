use v5.36;
package PlackX::Framework::Router {
  our $filters = {};
  our $bases   = {};
  our $engines = {};

  # Override in your subclass to change the export names
  sub filter_request_keyword { 'filter';       }
  sub route_request_keyword  { 'request';      }
  sub uri_base_keyword       { 'request_base'; }

  sub import ($class, @extra) {
    my $export_to = caller(0);

    # Trap errors
    die "You must import from your app's subclass of PlackX::Framework::Router, not directly"
      if $class eq __PACKAGE__;

    # Remember which controller is using which router engine object
    $engines->{$export_to} = $class->engine;

    # Export
    foreach my $export_sub (qw/filter_request route_request uri_base/) {
      my $get_export_name = $export_sub . '_keyword';
      my $export_name     = $class->$get_export_name;
      no strict 'refs';
      *{$export_to . '::' . $export_name} = \&{'DSL_' . $export_sub};
    }
  }

  sub engine ($class) {
    my $engine_class = $class . '::Engine';
    return $engine_class->instance;
  }

  sub DSL_filter_request ($when, $action, @slurp) {
    my ($package) = caller;

    die "usage: filter ('before' || 'after') => sub {}"
      unless $when eq 'before' or $when eq 'after';

    _add_filter($package, $when, {
      action     => _coerce_action_to_subref($action, $package),
      controller => $package,
      'when'     => $when,
      params     => \@slurp
    });
    return;
  }

  sub DSL_route_request (@args) {
    my ($package) = caller;
    my $action    = pop @args;
    my $routespec = shift @args;

    die 'expected coderef or hash as last argument'
      unless ref $action and (ref $action eq 'CODE' or ref $action eq 'HASH');

    if (@args) {
      my $verb = $routespec;
      $verb    = join('|', @$verb) if ref $verb;
      $routespec = shift @args;
      die 'incorrect usage' if ref $routespec;
      $routespec  = { $verb => $routespec };
    }

    $engines->{$package}->add_route(
      routespec   => $routespec,
      base        => $bases->{$package},
      prefilters  => _get_filters($package, 'before'),
      action      => _coerce_action_to_subref($action, $package),
      postfilters => _get_filters($package, 'after'),
    );
    return;
  }

  sub DSL_uri_base ($base) {
    my ($package) = caller;
    $bases->{$package} = _remove_trailing_slash($base);
    return;
  }

  # Class method-style (currently does not support base or filters) ###########
  sub add_route ($class, $spec, $action, %options) {
    my ($package) = caller;
    $options{'filter'} //= $options{'filters'};
    my $engine = ($engines->{$class} ||= $class->engine);
    $engine->add_route(
      routespec   => $spec,
      base        => $options{'base'}   ? _remove_trailing_slash($options{'base'}) : undef,
      prefilters  => $options{'filter'} ? _coerce_arrayref($options{'filter'}{'before'}) : undef,
      action      => _coerce_action_to_subref($action, $package),
      postfilters => $options{'filter'} ? _coerce_arrayref($options{'filter'}{'after' }) : undef,
    );
  }

  # Helpers ###################################################################
  sub _remove_trailing_slash ($uri) { substr($uri, -1, 1) eq '/' ? substr($uri, 0, -1) : $uri }
  sub _get_filters ($class, $when)  { $filters->{$class}{$when} }

  sub _add_filter ($class, $when, $spec) {
    $filters->{$class}{$when} ||= [];
    push @{   $filters->{$class}{$when}   }, $spec;
  }

  sub _coerce_action_to_subref ($action, $package) {
    if (not ref $action) {
      $action = ($action =~ m/::/) ?
        \&{ $action } : \&{ $package . '::' . $action };
    } elsif (ref $action and ref $action eq 'HASH') {
        # TODO: Make convenience methods in Response class to shorten these
        if (my $template = $action->{template}) {
          $action = sub ($request, $response) {
            $response->template->render($template);
          };
        } elsif (my $text = $action->{text}) {
          $action = sub ($request, $response) {
            $response->content_type('text/plain');
            $response->body($text);
            return $response;
          };
        } elsif (my $html = $action->{html}) {
          $action = sub ($request, $response) {
            $response->content_type('text/html');
            $response->body($html);
            return $response;
          };
        } else {
          die 'unknown action specification';
        }
    }
    return $action;
  }

  sub _coerce_arrayref ($val) { ref $val eq 'ARRAY' ? $val : [$val] }
}

1;

=pod

=head1 NAME

PlackX::Framework::Router - Parse routes and export DSL for PXF apps


=head1 SYNOPSIS

    package My::App::Controller;
    use My::App::Router;
    request_base '/myapp';

    filter before    => sub { ... }
    filter after     => sub { ... }
    request '/index' => sub { ... }


=head1 EXPORTS

This module exports the subroutines "filter", "request", and "request_base" to
the calling package. These can then be used like DSL keywords to lay out your
web app.

You can choose your own keyword names by overridding them in your subclass this
way:

    package MyApp::Router {
      use parent 'PlackX::Framework::Router';
      sub filter_request_keyword { 'my_filter'; }
      sub route_request_keyword  { 'my_route';  }
      sub uri_base_keyword       { 'my_base';   }
    }

=over 4

=item request_base STRING;

Set the base URI path for all subsequent routes.

=item filter ["before"|"after"} => sub { ... };

Filter all subsequent routes. Your filter subroutine should return a false
value to continue request processing. $response->continue is available for
a semantic convenience. To render a response early, return the response
object.

=item request $PATH     => sub { ... };

=item request $METHOD   => $PATH => sub { ... };

=item request $ARRAYREF => sub { ... };

=item request $HASHREF  => sub { ... };

Execute the subroutine for the matching route and path. The $PATH may contain
patterns described by PXF's routing engine, Router::Boom.

The $METHOD may contain more than one method, separated by a pipe, for
exampple, "get|post".

You may specify a list of $PATHs in an $ARRAYREF.

You may specify a hashref of key-value pairs, where the key is the HTTP
request method, and the value is the desired path.

See the section below for examples of various combinations.


=head1 EXAMPLES

    # Base example
    request_base '/myapp';

    # Filter example
    # Fat arrow operator allows us to use "before" or "after" without quotes.
    filter before => sub ($request, $response) {
      unless ($request->{cookies}{logged_in}) {
        $response->status(403);
        return $response;
      }
      $request->{logged_in} = 1;
      return;
    };

    # Simple route
    # Because of the request_base, this will actually match /myapp/index
    request '/index' => sub {
      ...
    };

    # Route with method
    request get => '/default' => sub { ... }
    request post => '/form'   => sub { ... }

    # Route with method, alternate formats
    request {get => '/login'} => sub {
      # show login form
      ...
    };

    request {post => '/login'} => sub {
      my $request  = shift;
      my $response = shift;

      # do some processing to log in a user..
      ...

      # successful login
      $request->redirect('/user/home');

      # reroute the request
      $request->reroute('/try_again');
    };

    # Route with arrayref
    request ['/list/user', '/user/list', '/users/list'] => sub {
      ...
    };

    # Routes with hashref
    request {post => '/path1', put => '/path1'} => sub {
      ...
    };

    # Route with pattern matching
    request {delete => '/user/:id'} => sub {
      my $request = shift;
      my $id = $request->route_param('id');
    };

    # Combination hashref arrayref
    request {get => ['/path1', '/path2']} => sub {
      ...
    };

    # Routes with alternate HTTP verbs
    request 'get|post' => '/somewhere' => sub { ... };


=head1 META

For author, copyright, and license, see PlackX::Framework.
