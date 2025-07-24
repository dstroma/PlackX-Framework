use v5.36;
package PlackX::Framework::Request {
  use parent 'Plack::Request';
  use Carp qw(croak);
  use Digest::MD5 ();

  use Plack::Util::Accessor qw(stash route_parameters);
  sub max_reroutes        { 16 }
  sub is_get      ($self) { uc $self->method eq 'GET'    }
  sub is_post     ($self) { uc $self->method eq 'POST'   }
  sub is_put      ($self) { uc $self->method eq 'PUT'    }
  sub is_delete   ($self) { uc $self->method eq 'DELETE' }
  sub is_ajax     ($self) { uc($self->header('X-Requested-With') || '') eq 'XMLHTTPREQUEST' }
  sub md5_ub64    ($str)  { Digest::MD5::md5_base64($str) =~ tr|+/=|-_|dr; }
  sub destination ($self) { $self->{destination} // $self->path_info   }
  sub flash       ($self) { $self->cookies->{$self->flash_cookie_name} }

  # param methods
  sub param       ($self, $key) { scalar $self->parameters->{$key} } # faster than scalar $self->param($key)
  sub cgi_param   ($self, $key) { $self->SUPER::param($key)        } # CGI.pm compatibile
  sub route_param ($self, $key) { $self->{route_parameters}{$key}  }
  sub stash_param ($self, $key) { $self->{stash}{$key}             }

  sub GlobalRequest ($class) {
    my $handler_class = $class->app_namespace . '::Handler';
    return $handler_class->global_request;
  }

  sub flash_cookie_name ($self) {
    # Memoize names so we don't have calculate the md5 each time
    # Keep the cookie name to 16 bytes
    state %names;
    $names{$self->app_namespace} ||= 'flash' . substr(md5_ub64($self->app_namespace),0,11);
  }

  sub reroute ($self, $dest) {
    my $routelist = $self->{reroutes} //= [$self->path_info];
    push @$routelist, ($self->{destination} = $dest);
    croak "Excessive reroutes:\n" . join("\n", @$routelist) if @$routelist > $self->max_reroutes;
    return $self;
  }

  sub urix ($self) {
    # The URI module is optional, so only load it on demand
    require PlackX::Framework::URIx;
    my $urix_class = $self->app_namespace . '::URIx';
    my $obj = eval {
      $urix_class->new_from_request($self)
    } || eval {
      PlackX::Framework::URIx->new_from_request($self)
    };
    return $obj;
  }
}

1;
