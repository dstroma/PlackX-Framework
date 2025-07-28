use v5.36;
package PlackX::Framework::Router::Engine {
  use parent 'Router::Boom';

  # We use a Hybrid Singleton (one instance per subclass)
  sub new      ($class) { $class->instance; }
  sub instance ($class) { state %instances; $instances{$class} ||= $class->SUPER::new }

  # Matching object methods ###########################################
  sub match ($self, $request) {
    die 'Usage: $engine->match($plackx_framework_request)'
      unless $request and ref $request and $request->can('destination');

    # Prefix with [ method ] to include in match
    my $destination = sprintf('/[ %s ]%s', $request->method, $request->destination);
    my ($match, $captures) = $self->SUPER::match($destination)
      or return undef;

    delete $captures->{PXF_REQUEST_METHOD}; # delete because internal use only
    $match->{route_parameters} = $captures;

    # Add global filters (the match already has local filters in it)
    for my $filter_type (qw/prefilters postfilters/) {
      if (my $filters = $self->_match_global_filters($filter_type, $request)) {
        $match->{$filter_type} ||= [];
        # put global prefilters before local and global postfilters after local
        unshift @{$match->{$filter_type}}, @$filters if $filter_type eq 'prefilters';
        push    @{$match->{$filter_type}}, @$filters if $filter_type eq 'postfilters';
      }
    }

    return $match;
  }

  sub _match_global_filters ($self, $kind, $request) {
    die "invalid kind of filters: '$kind'"
      unless $kind eq 'prefilters' or $kind eq 'postfilters';

    # Shortcut?
    return unless defined $self->{"global_$kind"};

    my @matches = ();
    foreach my $filter ($self->{"global_$kind"}->@*) {
      my $pattern = $filter->{'pattern'};
      push @matches, $filter->{action}
        if (!defined $pattern)
        or (ref $pattern eq 'SCALAR' and $request->destination eq $$pattern)
        or (ref $pattern eq 'Regexp' and $request->destination =~ $pattern)
        or (substr($request->destination, 0, length $pattern) eq $pattern);
    }
    return \@matches;
  }

  # Meta object methods - add route or global filter ##################
  sub add_route ($self, %params) {
    my $route   = delete $params{routespec};
    my $base    = delete $params{base};

    # Validate subroutine params
    die 'add_route(routespec => STRING|ARRAYREF|HASHREf)'
      unless ref $route eq 'HASH' or ref $route eq 'ARRAY' or not ref $route;

    # Process hashref like
    # { get => 'url1', post => 'url2' } or { get => ['url1', 'url2'] }
    if (ref $route eq 'HASH') {
      foreach my $key (keys %$route) {
        my $paths = ref $route->{$key} ? $route->{$key} : [$route->{$key}];
        $self->add(_path_with_base_and_method($_, $base, uc $key), \%params) for @$paths;
      }
      return;
    }

    # String or arrayref without HTTP verb
    $route = [$route] unless ref $route;
    $self->add(_path_with_base_and_method($_, $base), \%params) for @$route;
    return;
  }

  sub add_global_filter ($self, %params) {
    my $when    = delete $params{'when'};
    my $pattern = delete $params{pattern};
    my $action  = delete $params{action};

    # Validate subroutine params
    die q/Usage: add_global_filter(when => 'before'|'after', ...)/
      unless $when eq 'before' or $when eq 'after';

    my $prefix = $when eq 'before' ? 'pre' : 'post';
    my $hkey   = 'global_' . $prefix . 'filters';
    $self->{$hkey} ||= [];
    push @{$self->{$hkey}}, { pattern => $pattern, action => $action };
  }

  # Helper functions ##################################################
  sub _path_with_base ($path, $base) {
    return $path unless $base and length $base;
    $path = '/' . $path if substr($path, 0, 1) ne '/';
    return $base . $path;
  }

  sub _path_with_method ($path, $method = undef) {
    # $method can verb or verbs separated with pipe (e.g. 'get|post'), or undef
    # A real request uri should never have [] or spaces in it, so use those to
    # separate the method from the remaining uri. Thankfully Router::Boom does
    # not check uris for validity, otherwise this would not work.
    $method = $method ? ":$method" : '';
    $path   = "/[ {PXF_REQUEST_METHOD$method} ]$path";
    return $path;
  }

  sub _path_with_base_and_method ($path, $base, $method = undef) {
    $path = _path_with_base($path, $base);
    $path = _path_with_method($path, $method);
    return $path;
  }
}

1;

=pod

=head1 NAME

PlackX::Framework::Router::Engine


=head1 DESCRIPTION

This module provides route and global filter matching for PlackX::Framework.
Please see PlackX::Framework and PlackX::Framework::Router for details of how
to use routing and filters in your application.

=head2 Difference between Router and Router::Engine

The difference between PXF's ::Router module and the ::Router::Engine is that
the Router module is primarily responsible for exporting the routing DSL
and processing calls to add routes and filters, while the Router::Engine class
is responsible for storing routes and matching routes against requests.


=head1 CLASS METHODS

=over 4

=item new, instance

Return an object, creating a new one if one does not exist already.
This essentially allows each subclass to work as a singleton, so that there is
one PXF Router::Engine object per PXF application.

=back


=head1 OBJECT METHODS

=over 4

=item add_route

Adds a route. Please see documentation for PlackX::Framework::Router.
Do not add routes directly to the engine unless you wish to hack on the
framework.

=item add_global_filter

Adds a global filter. Please see documentation for PlackX::Framework::Router.
Do not add filters directly to the engine unless you wish to hack on the
framework.

=item match

Match a request against the route data. Returns the matched route and any
prefilters and postfilters that should be executed, or undef if no route
matches. The returned hashref contains the action to execute, filters
applicable to the route, and any parameters in the route, if applicable.

    {
      action           => CODEREF,
      prefilters       => ARRAYREF|undef,
      postfilters      => ARRAYREF|undef,
      route_parameters => HASHREF
    }

Again, PlackX::Framework handles this for you, so there should be no need to
use this method directly.

=back


=head1 META

For author, copyright, and license, see PlackX::Framework.

