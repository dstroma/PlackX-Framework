use v5.36;
package PlackX::Framework::Response {
  use parent 'Plack::Response';

  # Simple accessors and simple methods
  use Plack::Util::Accessor qw(stash cleanup_callbacks template);
  sub is_request        { 0     }
  sub is_response       { 1     }
  sub continue          { undef }
  sub stop              { $_[0] }
  sub flash_cookie_name { PlackX::Framework::Request::flash_cookie_name(shift) }
  sub print ($self, @lines)              { push @{$self->{body}}, @lines; $self     }
  sub add_cleanup_callback ($self, $sub) { push @{$self->{cleanup_callbacks}}, $sub }

  sub new ($class, @args) {
    my $self = $class->SUPER::new(@args);
    $self->{cleanup_callbacks} //= [];
    $self->{body}              //= [];
    return bless $self, $class;
  }

  sub GlobalResponse ($class) {
    my $handler_class = $class->app_namespace . '::Handler';
    return $handler_class->global_response;
  }

  sub redirect ($self, @args) {
    if (@args) {
      my $url = shift @args;
      $url = $self->add_prefix_to_url($$url) if ref $url;
      $url = $self->maybe_add_base_to_url($url);
      unshift @args, $url;
    }

    $self->SUPER::redirect(@args);
    return $self;
  }

  sub add_prefix_to_url ($self, $url) {
    if ($self->app_namespace->can('uri_prefix')) {
      my $prefix = $self->app_namespace->uri_prefix;
      $prefix = substr($prefix, 0, length $prefix - 1) if substr($prefix, -1, 1) eq '/';
      $url = substr($url, 1) if substr($url, 0, 1) eq '/';
      $url = join('/', $self->app_namespace->uri_prefix, $url);
    }
    if ($url !~ m`://` and my $request = ($self->stash->{REQUEST} || $self->GlobalRequest)) {
      $url = substr($url, 1) if substr($url, 0, 1) eq '/';
      $url = $request->base . $url;
    }
    return $url;
  }

  sub maybe_add_base_to_url ($self, $url) {
    warn "maybe_add_base_to_url is inop";
    return $url;
    if ($url !~ m`://` and my $request = (($self->stash && $self->stash->{REQUEST}) || $self->GlobalRequest)) {
      $url = substr($url, 1) if substr($url, 0, 1) eq '/';
      $url = $request->base . $url;
    }
    return $url;
  }

  sub no_cache ($self, $bool) {
    my $val = $bool ? 'no-cache' : undef;
    $self->header('Pragma' => $val, 'Cache-control' => $val);
  }

  sub flash ($self, $value //= '') {
    # Values are automatically encoded by Cookie::Baker
    my $max_age = $value ? 300 : -1; # If value is false we delete the cookie
    $self->cookies->{flash_cookie_name($self)} = { value=>$value, path=>'/', 'max-age'=>$max_age, samesite=>'strict' };
    return $self;
  }

  sub flash_redirect ($self, $flashval, $url) {
    return $self->flash($flashval)->redirect($url, 303);
  }

  sub render_json ($self, $data)     { $self->render_content('application/json', encode_json($data)) }
  sub render_text ($self, $text)     { $self->render_content('text/plain',       $text             ) }
  sub render_html ($self, $html)     { $self->render_content('text/html',        $html             ) }
  sub render_template ($self, @args) { $self->{template}->render(@args); $self }

  sub render_content ($self, $content_type, $body) {
    $self->status(200);
    $self->content_type($content_type);
    $self->body($body);
    return $self;
  }

  sub encode_json ($data) {
    require JSON::MaybeXS;
    state $json = JSON::MaybeXS->new(utf8 => 1);
    return $json->encode($data);
  }
}

1;
