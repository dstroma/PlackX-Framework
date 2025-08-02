use v5.36;
package PlackX::Framework::Role::RouterEngine {
  use Role::Tiny;
  requires qw(new instance match add_route add_global_filter);
}

1;
