#!perl
use v5.36;
package MyApp {
  use PlackX::Framework qw(:template :urix);
  use MyApp::Template;
  use MyApp::GlobalFilters;
  use MyApp::Controllers;

  sub uri_prefix { '/example-base' }
}

1;
