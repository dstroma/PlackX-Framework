use v5.36; # strict (5.12), warnings (5.35), signatures (5.36)
package PlackX::Framework 0.24 {
  use List::Util qw(any);
  use Module::Loaded ();
  use Digest::MD5 ();

  our @plugins = ();
  sub required_modules { qw(Handler Request Response Router Router::Engine) }
  sub optional_modules { qw(URIx Template Config), @plugins }

  # Export ->app, load parent classes and load or create subclasses
  sub import (@options) {
    my %required   = map { $_ => 1 } required_modules(); # not memoized to save ram
    my $all_wanted = any { $_ =~ m/^[:+]all$/ } @options;
    my $mod_wanted = $all_wanted ? sub {1} : sub { any { $_ =~ m/^[:+]{0,2}$_[0]$/i } @options };
    my $caller     = caller(0);
    export_app_sub($caller);

    # Load or create required modules, attempt to load optional ones
    # Distinguish between modules not existing and modules with errors
    foreach my $module (required_modules(), optional_modules()) {
      eval 'require PlackX::Framework::'.$module
        or die $@ if $required{$module};
      eval 'require '.$caller.'::'.$module or do {
        die $@ if module_is_broken($caller.'::'.$module);
        generate_subclass($caller.'::'.$module, 'PlackX::Framework::'.$module)
          if $required{$module} or $all_wanted or $mod_wanted->($module);
      };
      export_app_namespace_sub($caller, $module)
        if Module::Loaded::is_loaded($caller.'::'.$module);
    }
  }

  # Export app() sub to the app's main package
  sub export_app_sub ($destination_namespace) {
    no strict 'refs';
    *{$destination_namespace . '::app'} = sub ($class, @options) {
      ($class.'::Handler')->to_app(@options);
    };
  }

  # Export app_namespace() to App::Request, App::Response, etc.
  sub export_app_namespace_sub ($namespace, $module) {
    no strict 'refs';
    my $exists = eval $namespace.'::'.$module.'::app_namespace()';
    die "app_namespace(): expected $namespace, got $exists" if $exists and $exists ne $namespace;
    *{$namespace.'::'.$module.'::app_namespace'} = sub { $namespace } unless $exists;
  }

  # Helper to create a subclass and mark as loaded
  sub generate_subclass ($new_class, $parent_class) {
    eval "package $new_class; use parent '$parent_class'; 1" or die "Cannot create class: $@";
    Module::Loaded::mark_as_loaded($new_class);
  }

  # Utility functions
  sub flash_cookie_name ($class) {
    # Keep name to 16B. Memoize so we don't have calculate the md5 each time.
    state %mem;
    $mem{$class} ||= 'flash'.substr(md5_ubase64($class),0,11);
  }

  sub md5_ubase64      ($str) { Digest::MD5::md5_base64($str) =~ tr|+/=|-_|dr; }
  sub module_is_broken ($mod) { my $fn = module_to_file($mod); exists $INC{$fn} and !defined $INC{$fn} }
  sub module_to_file   ($mod) { Module::Loaded->_pm_to_file($mod) }
}

1;

=pod

=head1 NAME

PlackX::Framework - A thin framework for PSGI/Plack web apps.


=head1 SYNOPSIS

This is a small framework for PSGI web apps, based on Plack. A simple
PlackX::Framework application could be all in one .psgi file:

    # app.psgi
    package MyProject {
      use PlackX::Framework; # loads and sets up the framework and subclasses
      use MyProject::Router; # exports router DSL
      route '/' => sub ($request, $response) {
         $response->body('Hello, ', $request->param('name'));
         return $response;
      };
    }
    MyProject->app;

A larger application would be typically laid out with separate modules in
separate files, for example in MyProject::Controller::* modules. Each should
use MyProject::Router if the DSL-style routing is desired.

This software is considered to be in an experimental, "alpha" stage.


=head1 DESCRIPTION

=head2 Overview and Required Components

PlackX::Framework consists of the required modules:

=over 4

=item PlackX::Framework

=item PlackX::Framework::Handler

=item PlackX::Framework::Request

=item PlackX::Framework::Response

=item PlackX::Framework::Router

=item PlackX::Framework::Router::Engine

=back

And the following optional modules:

=over 4

=item PlackX::Framework::Config

=item PlackX::Framework::Template

=item PlackX::Framework::URIx

=back

The statement "use PlackX::Framework" will automatically find and load all of
the required modules. Then it will look for subclasses of the modules listed 
above that exist in your namespace and load them, or create empty subclasses
for any required modules that do not exist. The following example

    package MyProject {
        use PlackX::Framework;
        # ...app logic here...
    }

will attempt to load MyProject::Handler, MyProject::Request,
MyProject::Response and so on, or create them if they do not exist.

You only use, not inherit from, PlackX::Framework. However, your
::Handler, ::Request, ::Response, etc. classes should inherit from
PlackX::Framework::Handler, ::Request, ::Response, and so on.


=head2 Optional Components

The Config, Template and URIx modules are included in the distribution, but
loading them is optional to save memory and compile time when not needed.
Just as with the required modules, you can subclass them yourself, or you can
have them automatically generated.

To set up all optional modules, use the :all (or +all) tag in your use line.

    # The following are equivalent
    use PlackX::Framework qw(:all);
    use PlackX::Framework qw(+all);

Note that 'use Module -option' syntax is not supported, because it can be mis-
read by human readers as "minus option" which might make them think the intent
is to turn the specified option off.

If you want to pick certain optional modules, you can specify those
individually with the name of the module, optionally preceded by a single
double colon (: or ::) or a plus sign. You may also use lower case.

    # All of the below are equivalent
    use PlackX::Framework qw(Config Template);
    use PlackX::Framework qw(:Config :Template);
    use PlackX::Framework qw(:config :template);
    use PlackX::Framework qw(::Config ::Template);
    use PlackX::Framework qw(+Config +Template);

Third party developers can install additional optional components, by pushing
to the @PlackX::Framework::plugins array. These can then be loaded by PXF the
same way as the optional modules described above.


=head2 The Pieces and How They Work Together

=head3 PlackX::Framework

PlackX::Framework is basically a management module, that is responsible for
loading required and optional components. It will automatically subclass
required, and desired optional classes for you if you have not done so already.
It exports one symbol, app(), to the calling package; it also exports an
app_namespace() sub to your app's subclasses, which returns the name of the
root class.

  # Example app
  package MyApp {
    # The following statement will load, or automatically create,
    # MyApp::Handler, MyApp::Request, MyApp::Response, MyApp::Router, etc.
    # It will create a MyApp::app() function, and an app_namespace() function
    # in each respective subclassed module if one does not already exist.
    use PlackX::Framework qw(:all);
  }



=head3 PlackX::Framework::Handler

PlackX::Framework::Handler is the package responsible for request processing.
You would not normally have to subclass this module manually unless you would
like to customize its behavior. It will prepare request and response objects,
a stash, and if set up, templating.


=head3 PlackX::Framework::Request

=head3 PlackX::Framework::Response

The PlackX::Framework::Request and PlackX::Framework::Response modules are
subclasses of Plack::Request and Plack::Response sprinkled with additional
features, described below.

=over 4

=item stash()

Both feature a shared "stash" which is a hashref in which you can store any
data you would like. The "stash" is not a user session but a way to
temporarily store information during a request/response cycle. It is
re-initialized for each cycle.

=item flash()

They also feature a "flash" cookie which you can use to store information on
the user end for one cycle. It is automatically cleared in the following
cycle. For example...

    $response->flash('Goodbye!'); # Store message in a cookie

On the next request:

    $request->flash; # Returns 'Goodbye!'.

During the response phase, the flash cookie is cleared, unless you set another
one.

=back

=head3 PlackX::Framework::Router

This module exports the route, route_base, global_filter, and filter functions
to give you a minimalistic web app controller DSL. You can import this into
your main app package, as shown in the introduction, or separate packages.

    # Set up the app
    package MyApp {
      use PlackX::Framework;
    }

    # Note: The name of your controller module doesn't matter, but it must
    # import from your router subclass, e.g., MyApp::Router, not directly from
    # PlackX::Framework::Router!
    package MyApp::Controller {
      use MyApp::Router;

      base '/app';

      global_filter before => sub {
        # I will be executed for ANY route ANYWHERE in MyApp!
        ...
      };

      filter before => sub {
        # I will only be executed for the routes listed below in this package.
        ...
      };

      route '/home' => sub {
        ...
      };

      route { post => '/login' } => sub {
        ...
      };
    }


=head3 PlackX::Framework::Router::Engine

The PlackX::Framework::Router::Engine is a subclass of Router::Boom with some
extra convenience methods. Normally, you would not have to use this module
directly. It is used by PlackX::Framework::Router internally.


=head3 PlackX::Framework::Config

This module is provided primarily for convenience. Currently not used by PXF
directly except you may optionally store template system configuration there.


=head3 PlackX::Framework::Template

The PlackX::Framework::Template module can automatically load and set up
Template Toolkit, offering several convenience methods. If you desire to use
a different templating system from TT, you may override as many methods as
necessary in your subclass. A new instance of this class is generated for
each request by the app() method of PlackX::Framework::Handler.


=head3 PlackX::Framework::URIx

The optional PlackX::Framework::URIx module is a subclass of URI::Fast, with
some syntactic sugar for manipulating query string. It is made available to
your request objects through $request->urix (the x is to not confuse it
with the Plack::Request uri method).


=head1 Why Another Framework?

Plack comes with several modules that make it possible to create a bare-bones
web app, but as described in the documentation for Plack::Request, this is a
very low-level way to do this. A framework is recommended. This package
provides a minimalistic framework which takes Plack::Request, Plack::Response,
and several other modules and ties them together.

The end result is a simple, lightweight framework that is higher level
than using the raw Plack building blocks, although it does not have as many
features as other frameworks. Here are some advantages:

=over 4

=item Load Time

A basic PlackX::Framework "Hello World" application loads 75% faster
than a Dancer2 application and 70% faster than a Mojolicious::Lite app.
(The author has not benchmarked request/response times.)

=item Memory

A basic PlackX::Framework "Hello World" application uses approximately
one-third the memory of either Dancer2 or Mojolicious::Lite (~10MB compared
to ~30MB for each of the other two).

=item Dependencies

PlackX::Framework has few non-core dependencies (it has more than
Mojolicious, which has zero, but fewer than Dancer2, which has a lot.)

=item Magic

PlackX::Framework has some magic, but not too much. It can be easily
overriden with subclassing. You can use the bundled router engine
or supply your own. You can use Template Toolkit automatically or use
a different template engine.

=back

The author makes no claims that this framework is better than any other
framework except for the few trivial metrics described above. It has been
published in the spirit of TIMTOWDI.


=head2 Object Orientation and Magic

PlackX::Framework has an object-oriented design philosophy that uses both
inheritance and composition to implement its features. Symbols exported are
limited to avoid polluting your namespace, however, a lot of the "magic" is
implemented with the import() method, so be careful about using empty
parenthesis in your use statements, as this will prevent the import() method
from being called and may break some magic.

Also be careful about whether you should use a module or subclass it.
Generally, modifying the behavior of the framework itself will involve
subclassing, while using the framework will not.


=head2 Configuration

=head3 uri_prefix

In your application's root namespace, you can set the base URL for requests
by defining a uri_prefix subroutine.

    package MyApp {
      use PlackX::Framework;
      sub uri_prefix { '/app' }
    }


=head2 Routes, Requests, and Request Filtering

See PlackX::Framework::Router for documentation on request routing and
filtering.


=head2 Templating

No Templating system is loaded by default, but PlackX::Framework can
automatically load and set up Template Toolkit if you:

    use MyProject::Template;

(assuming MyProject has imported from PlackX::Framework).

Note that this feature relies on the import() method of your app's
PlackX::Framework::Template subclass being called (this subclass is also
created automatically if you do not have a MyApp/Template.pm file).
Therefore, the following will not load Template Toolkit:

    use MyApp::Template ();  # Template Toolkit is not loaded
    require MyApp::Template; # Template Toolkit is not loaded

If you want to supply Template Toolkit with configuration options, you can
add them like this

    use MyApp::Template (INCLUDE_PATH => 'template');

If you want to use your own templating system, create a MyApp::Template
module that subclasses PlackX::Framework::Template. Then override the
get_template_system_object() method with your own code to create and/or
retrieve your template system object.


=head2 Model Layer

This framework is databse/ORM agnostic, you are free to choose your own or use
plain DBI/SQL.


=head1 EXPORT

This module will export the method app, which returns the code reference of
your app in accordance to the PSGI specification. (This is actually a shortcut
to [ProjectName]::Handler->to_app.)


=head1 DEPENDENCIES

=head2 Required

=over 4

=item perl 5.36 or greater

=item Plack

=item Router::Boom

=back


=head2 Optional

=over 4

=item Config::Any

=item Template

=item URI::Fast

=back

=head1 SEE ALSO

=over 4

=item PSGI

=item Plack

=item Plack::Request

=item Plack::Response

=item Router::Boom

=back


=head1 AUTHOR

Dondi Michael Stroma, E<lt>dstroma@gmail.com<gt>


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016-2025 by Dondi Michael Stroma


=cut
