use v5.36;
package PXF::Exporter {
  use Carp ();
  sub import ($class, @params) {
    return unless @params;
    my $caller = caller(0);
    foreach my $name (@params) {
      Carp::croak qq(You probably should not import "$name")
        if $name !~ m/^[a-z][a-z0-9_]*$/ or ($name eq 'import' and !$class->isa(__PACKAGE__));
      { no strict 'refs'; *{$caller.'::'.$name} = \&{$class.'::'.$name}; }
    }
  }
}

1;

=pod

=head1 NAME

PlackX::Framework::Exporter

=head1 DESCRIPTION

A very simple exporter. Use it in your module like this:

    package MyPackage {
      use PlackX::Framework::Exporter qw(import);
      sub a { ... }
      sub b { ... }
      ...
    }

Then users of your module can import anything they want, provided
the name is lower case and it doesn't start with _.

    package MyConsumer {
      use MyPackage qw(a b ...);
    }

=head1 META

See PlackX::Framework.
