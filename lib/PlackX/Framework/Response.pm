use v5.36;
package PlackX::Framework::Response {
  use parent 'Plack::Response';

  use Plack::Util::Accessor qw(stash cleanup_callbacks template);
  sub GlobalResponse ($class)            { ($class->app_namespace.'::Handler')->global_response }
  sub continue                           { undef      }
  sub stop                               { $_[0] || 1 }
  sub print ($self, @lines)              { push @{$self->{body}}, @lines; $self     }
  sub add_cleanup_callback ($self, $sub) { push @{$self->{cleanup_callbacks}}, $sub }
  sub flash_cookie_name ($self)          { PlackX::Framework::flash_cookie_name($self->app_namespace) }

  sub new ($class, @args) {
    my $self = $class->SUPER::new(@args);
    $self->{cleanup_callbacks} //= [];
    $self->{body}              //= [];
    return bless $self, $class;
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

  sub flash ($self, $value = undef) {
    # Values are automatically encoded by Cookie::Baker
    $value //= '';
    my $max_age = $value ? 300 : -1; # If value is false we delete the cookie
    $self->cookies->{$self->flash_cookie_name} = { value=>$value, path=>'/', 'max-age'=>$max_age, samesite=>'strict' };
    return $self;
  }

  sub flash_redirect ($self, $flashval, $url) {
    return $self->flash($flashval)->redirect($url, 303);
  }

  sub render_json     ($self, $data) { $self->render_content('application/json', encode_json($data)) }
  sub render_text     ($self, $text) { $self->render_content('text/plain',       $text             ) }
  sub render_html     ($self, $html) { $self->render_content('text/html',        $html             ) }
  sub render_template ($self, @args) { $self->{template}->render(@args); $self }

  sub render_content ($self, $content_type, $body) {
    $self->status(200);
    $self->content_type($content_type);
    $self->body($body);
    return $self;
  }

  sub encode_json ($data) {
    return $data unless ref $data;
    require JSON::MaybeXS;
    state $json = JSON::MaybeXS->new(utf8 => 1);
    return $json->encode($data);
  }
}

1;

=pod

=head1 NAME

PlackX::Framework::Response - Subclass of Plack::Response for PlackX::Framework


=head1 CLASS METHODS

=over 4

=item new()

Returns a new object. This is done for you by the framework.

=item GlobalResponse()

If your app's subclass of PlackX::Framework::Handler's
use_global_request_response method returns a true value, PlackX::Framework
will set up a global response object for you, which can be retrieved via this
class method.

This feature is turned off by default to avoid action-at-a-distance bugs. It
is preferred to use the request object instance passed to each route's
subroutine.

=back


=head1 OBJECT METHODS

=over 4

=item continue()

Syntactic sugar for returning a false value. Indicates to PlackX::Framework
to execute the next matching route or filter.

    return $response->continue; # equivalent to return;

See also the stop() method below.

=item flash(value)

Sets the flash cookie to the value specified, or clears it if the value is
false. PXF automatically clears the cookie on the subsequent request, unless
you set a different one.

=item flash_redirect(value, url)

Combines flash(value) and redirect(url) with a 303 (SEE OTHER) response code.

=item no_cache(BOOL)

If passed a true value, adds HTTP Pragma and Cache-Control headers to "no-cache".
If passed a false value, sets these headers to empty string.

=item print($string), print(@strings)

Adds $string or @strings to the response body.

=item render_html($string)

Sets the content-type to text/html and sets the response body to $string.

=item render_json($ref)

Sets the content-type to application/json and encodes $ref to JSON, setting
the response body to the resulting string.

=item render_template(@args)

Shortcut for template->render(@ags)

=item render_text($string)

Sets the content-type to text/plain and sets the response body to $string.

=item stash(), stash($hashref)

Returns the current stash hashref, optionally setting it to a new one.

=item stop()

Syntactic sugar for returning the object itself. Indicates to PlackX::Framework
that it should render the response.

    return $response->stop; # equivalent to return $response;

=item template()

Returns the PlackX::Framework::Template object, or undef if templating has not
been set up.

=back


=head1 META

For author, copyright, and license, see PlackX::Framework.
