use v5.36;
package PlackX::Framework::Router {
  our $filters = {};
  our $bases   = {};
  our $engines = {};

  sub import ($class, @extra) {
    my $export_to = caller(0);

    # Trap errors
    die "You must import from your app's subclass of PlackX::Framework::Router, not directly"
      if $class eq __PACKAGE__;

    # Remember which controller is using which router engine object
    $engines->{$export_to} = $class->engine;

    # Export
    no strict 'refs';
    *{$export_to . '::' . $_} = \&{'DSL_'.$_} for qw(filter request request_base);
  }

  sub engine ($class) {
    my $engine_class = $class . '::Engine';
    return $engine_class->instance;
  }

  sub DSL_filter ($when, $action, @slurp) {
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

  sub DSL_request (@args) {
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

  sub DSL_request_base ($base) {
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

Examples:

package My::App::Controller;
use My::App::Router;

filter 'before' => sub {
  my $request  = shift;
  my $response = shift;
  
  unless ($request->{cookies}{logged_in}) {
    $response->status(403);
    return $response;
  }
  $request->{logged_in} = 1;
  return;
};

request '/index' => sub {
  ...
  $template->render_index;
};

request get => '/default' => sub { }
request post => '/form'   => sub { }

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

request ['/list/user', '/user/list', '/users/list'] => sub {
  ...
};

request {post => '/path1', put => '/path1'} => sub {
  ...
};

request {delete => '/user/:id'} => sub {
   ...
};

request {get => ['/path1', '/path2']} => sub {

};

request 'get|post' => '/somewhere' => sub {};


