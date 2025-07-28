use v5.36;
package PlackX::Framework::Router::Engine {
  use parent 'Router::Boom';

  # We use a Hybrid Singleton (one instance per inherited class)
  my %instances;
  sub instance ($class) { $instances{$class} ||= $class->new; }

  # Matching object methods ###########################################
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
        $self->add(path_with_base_and_method($_, $base, uc $key), \%params) for @$paths;
      }
      return;
    }

    # String or arrayref without HTTP verb
    $route = [$route] unless ref $route;
    $self->add(path_with_base_and_method($_, $base), \%params) for @$route;
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
  sub path_with_base ($path, $base) {
    return $path unless $base and length $base;
    $path = '/' . $path if substr($path, 0, 1) ne '/';
    return $base . $path;
  }

  sub path_with_method ($path, $method = undef) {
    # $method can be undef, http verb, or verbs separated with pipe (e.g. 'get|post')
    $method = $method ? ":$method" : '';
    $path   = "/[{PXF_REQUEST_METHOD$method}]$path";
    return $path;
  }

  sub path_with_base_and_method ($path, $base, $method = undef) {
    $path = path_with_base($path, $base);
    $path = path_with_method($path, $method);
    return $path;
  }
}

package PlackX::Framework::Router::Engine::Match {
  use Plack::Util::Accessor qw(action prefilters postfilters);
}

1;

=pod

=head1 NAME

PlackX::Framework::Router::Engine


=head1 DESCRIPTION

This module provides route and global filter matching for PlackX::Framework.
Please see PlackX::Framework and PlackX::Framework::Router for details of how
to use routing and filters in your application.


=head1 CLASS METHODS

=over 4

=item new

Create a new object.

=item instance

Return a singleton object, creating a new one if one does not exist already.

=back


=head1 OBJECT METHODS

=over 4

=item add_route

=item add_global_filter

=item match

=item match_global_filters

=back


=head1 FUNCTIONS

=over 4

=item path_with_base($path, $base)

Prefix $path with $base, adding a forward slash if necessary.

=item path_with_method($path, $method|undef)

Prefix $path with a route parameter optionally matching $method.

=item path_with_base_and_method($path, $base, $method|undef)

Combines the above functions.


=head1 META

For author, copyright, and license, see PlackX::Framework.

