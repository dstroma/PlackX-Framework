use v5.36;
package PlackX::Framework::Template {
  my %engine_objects = ();

  sub import ($class, $options = undef) {
    die "Import from your app's subclass of PlackX::Framework::Template, not directly"
      if $class eq __PACKAGE__;

    # Do nothing if engine is already set up or if :manual tag is passed
    return if $class->get_engine;
    return if $options and not ref $options and ($options eq ':manual' or $options eq ':no-auto');

    # Setup Template Toolkit if available
    # Options can be passed in import statement or in config file
    require Template;
    unless ($options) {
      $options = eval {
        my $config = $class->app_namespace->config();
        return $config->{pxf}{template} if $config->{pxf}{template};
        return $config->{pxf_template}  if $config->{pxf_template};
        return undef;
      };
    }

    # Set up some sane defaults if necessary
    $options = {} unless $options;
    $options->{'INCLUDE_PATH'} //= ['template', 'templates'];

    # Create and remember the Template-Toolkit object to be used
    my $template_toolkit_obj = Template->new($options);
    $class->set_engine($template_toolkit_obj);
  }

  sub new ($class, $response, $engine = undef) {
    die 'Usage: ->new($response_object)' unless $response and ref $response;

    $engine = $class->get_engine() unless $engine;
    die 'No valid template engine object' unless $engine and ref $engine;

    return bless { engine => $engine, params => {}, response => $response }, $class;
  }

  sub output ($self, $file = undef, $params = undef) {
    $self->set_params(%$params) if $params and ref $params and ref $params eq 'HASH';
    $file //= $self->{filename};
    $self->{engine}->process($file, $self->{params}, $self->{response}) || die 'Template error: '.$self->{engine}->error;
  }

  sub self_to_class ($self)         { ref $self ? ref $self : $self }
  sub get_engine ($self)            { $engine_objects{self_to_class $self} }
  sub set_engine ($self, $new)      { $engine_objects{self_to_class $self} = $new }
  sub set_filename ($self, $fname)  { $self->{filename} = $fname }
  sub get_param ($self, $name)      { $self->{params}{$name}     }
  sub set_params ($self, %params)   { @{$self->{params}}{keys %params} = values %params; $self }
  sub render ($self, @args)         { $self->output(@args); $self->{response} }
  *set = \&set_params;
  *use = \&set_filename;
}

1;

=pod

=head1 NAME

PlackX::Framework::Template - Use templates in a PlackX::Framework app.


=head1 SYNOPSIS

This module allows a convenient way to select template files, add parameters,
and process and output the templates. By default, the Template Toolkit module
('Template') is used as the engine, but you can use your own.

If using Template Toolkit, you can pass options to Template->new by including
a hashref in your use statement:

    # Your app
    package MyApp {
      use PlackX::Framework; # (automatically generates MyApp::Template...)
      use MyApp::Template { OPTION => 'value', ... };
    }

Your PlackX::Framework app will automatically create a new instance of this
class and make it available to your $response object.

    # In your controller
    my $template = $response->template;
    $template->set_filename('foobar.tmpl'); # or ->use('foobar.tmpl');
    $template->add_params(food => 'pizza', drink => 'beer'); # or ->set(...)
    return $template->render;


=head1 CUSTOM TEMPLATE ENGINE

To use your own, subclass this module and override get_engine() method to
return an instance of your templating engine object. If your engine does not
have a Template Toolkit-like process() method, you will have to override the
output() method of this module as well.

This example assumes you reuse the same template object for each request:

    package MyApp::Template {
      my $templater = Some::Template::Engine->new;
      sub get_engine { $templater; }
      sub output ($self, $file) {
        $self->get_engine->render($file, $self->{'params'}->%*);
      }
    }

However you can also create a new one for each request:

    package MyApp::Template {
      sub get_engine { Some::Template::Engine->new() }
      sub output ($self, $file) {
        $self->get_engine->render($file, $self->{'params'}->%*);
      }
    }

As an example, consider an extremely simple template engine that simply
replaces {{variable}} with the value of key 'variable' in the params:

    package MyTemplateEngine {
      sub new { bless {}, shift }
      sub process ($self, $file, $params, $response) {
        my $content = readfile($file); # readfile() implementation not shown
        foreach my ($key, $val) (%$params) {
          $content =~ s`\{\{$key\}\}`$val`g;
        }
        $response->print($content);
      }
    }

Which we can use our new engine in our PlackX::Framework app like this:

    package MyApp::Template {
      use parent 'PlackX::Framework::Template';
      sub get_engine { MyTemplateEngine->new() }
    }

In this case, there is no need to override output() as our engine's process()
method is TT-like.


=head1 CLASS METHODS

=head2 new($response)
=head2 new($response, $engine)

Create a new instance of this class, optionally specifying the
template engine. If not specified, get_engine() will be called.

The first argument, a PlackX::Framework response object, is required.


=head2 get_engine

Get the Template engine object (e.g., the Template Toolkit instance).

=head2 set_engine($obj)

Set the Template engine object (e.g., the Template Toolkit instance).


=head1 OBJECT METHODS

=head2 get_param($key)

Get the value of a template parameter.

=head2 set_params($k => $v, $k2 => $v2...)
=head2 set(...)

Set the value of template parameters. Aliased as set() for short.

=head2 set_filename($filename)
=head2 use(...)

Set the template filename to be automatically passed to output().
Aliased as use() for short.

=head2 output
=head2 output($filename)

Process the template file, to optionally include the filename which will
override any previous calls to set_filename() or use().

=head2 render(...)

Call the output(...) method, passing the same arguments, and return the
Plack response object.
