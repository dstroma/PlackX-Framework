use v5.36;
package PlackX::Framework::Role::RouterEngine {
  use Role::Tiny;
  requires qw(new instance match add_route add_global_filter);
}

1;

=pod

=head1 NAME

PlackX::Framework::Role::RouterEngine


=head1 SYNOPSIS

    package My::Router::Engine {
        use Role::Tiny::With;
        with 'PlackX::Framework::Role::RouterEngine';
        sub new       { ... }
        sub instance  { ... }
        sub match     { ... }
        sub add_route { ... }
        sub add_global_filter { ... }
    }


=head1 DESCRIPTION

This module defines a role which is useful in writing a custom Router::Engine
class for PlackX::Framework.

The Engine class shall be a singleton which returns the same instance for a
particular class (meaning subclasses should get difference instances) whenever
new() or instance() is called.


=head1 REQUIRED OBJECT METHODS

=over 4

=item new, instance

Return an instance of the class.

=item $obj->match($request)

Using a PlackX::Framework::Request object to find a matching route. The return
value shall be undef or false if no match is found. If a match is found, a
hashref should be returned.

The hashref should contain the following keys:

TBD.

=item $obj->add_route(...)

Add a route.

=item $obj->add_global_filter(...)

Add a global filter.

=back


=head1 META

For copyright and license, see PlackX::Framework.

