use v5.36;
package PlackX::Framework::Request {
  use parent 'Plack::Request';
  use Carp qw(croak);
  use Digest::MD5 ();

  use Plack::Util::Accessor qw(stash route_parameters);
  sub max_reroutes      { 16 }
  sub is_request        { 1 }
  sub is_response       { 0 }
  sub is_get    ($self) { uc $self->method eq 'GET'    }
  sub is_post   ($self) { uc $self->method eq 'POST'   }
  sub is_put    ($self) { uc $self->method eq 'PUT'    }
  sub is_delete ($self) { uc $self->method eq 'DELETE' }
  sub is_ajax   ($self) { uc($self->header('X-Requested-With') || '') eq 'XMLHTTPREQUEST' }
  sub destination ($self)        { $self->{destination} // $self->path_info        }
  sub param ($self, $key)        { scalar $self->parameters->{$key}                } # faster than scalar $self->param($key)
  sub cgi_param ($self, $key)    { $self->SUPER::param($key)                       } # CGI.pm compatibility
  sub route_param ($self, $name) { $self->{route_parameters}{$name}                }
  sub stash_param ($self, $name) { $self->{stash}{$name}                           }
  sub flash_cookie_name ($self)  { 'flash' . md5_ub64($self->app_namespace)        }
  sub flash ($self)              { $self->cookies->{$self->flash_cookie_name}      }
  sub md5_ub64 ($str)            { Digest::MD5::md5_base64($str) =~ tr|+/=|-_|dr;  }

  sub GlobalRequest ($class) {
    my $handler_class = $class->app_namespace . '::Handler';
    return $handler_class->global_request;
  }

  sub reroute ($self, $dest) {
    my $routelist = $self->{reroutes} //= [$self->path_info];
    push @$routelist, ($self->{destination} = $dest);
    croak "Excessive reroutes:\n" . join("\n", @$routelist) if @$routelist > $self->max_reroutes;
    return $self;
  }

  sub urix ($self) {
    # The URI module is optional, so only load it on demand
    require Module::Loaded;
    require PlackX::Framework::URIx;
    my $urix_class = $self->app_namespace . '::URIx';
    $urix_class = 'PlackX::Framework::URIx'
      unless Module::Loaded::is_loaded($urix_class) or eval "require $urix_class; 1";
    return $urix_class->new_from_request($self);
  }
}

1;
