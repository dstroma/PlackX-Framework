#!perl
use v5.36;
use Test::More;
use Try::Tiny;
our $verbose = grep { $_ eq '-v' or $_ eq '--verbose' } @ARGV;

do_tests();
done_testing();

#######################################################################

sub do_tests {

  my $uri_fast_available = eval { require URI::Fast; 1 };
  unless ($uri_fast_available) {
    say 'URI::Fast not available, skipping applicable tests';
    return;
  }

  my $class = 'PlackX::Framework::URIx';
  use_ok($class);

  my $uri = $class->new('http://www.google.com/?search=xxx');
  ok($uri, 'Successfully call method new()');
  ok(ref $uri && $uri->isa($class), 'Got an object');

  $uri->query_set(search => 'best linux distro');
  ok($uri !~ m/xxx/ && $uri =~ m/best(\+|\%20)linux(\+|\%20)distro/, 'Old params should be overwritten by query_set');
  say $uri if $verbose;

  $uri->query_add(search => 'perl');
  ok($uri =~ m/search=best(\+|\%20)linux(\+|\%20)distro/ && $uri =~ m/search=perl/, 'Old params should be kept and new added by query_add');
  say $uri if $verbose;

  $uri->query_delete_all();
  ok($uri !~ m/search/ && $uri !~ m/perl/, 'All params should be deleted by query_delete_all');
  say $uri if $verbose;

  $uri->query_add(param1 => 'one', param2 => 'two');
  ok($uri =~ m/param1/ && $uri =~ m/param2/ && $uri =~ m/one/ && $uri =~ m/two/, 'Can add multiple params at once');
  say $uri if $verbose;

  $uri->query_delete_all();
  $uri->query_set(param_a => 'apple', param_b => 'banana');
  ok($uri =~ m/param_a=apple/ && $uri =~ m/param_b=banana/, 'Can set multiple params at once');
  say $uri if $verbose;

  $uri->query_delete('param_b', 'blah');
  ok($uri !~ m/param_b/ && $uri =~ m/param_a/ && $uri !~ m/blah/, 'Delete a single param');
  say $uri if $verbose;

  $uri = $class->new('http://www.google.com/?car=edsel&cart=shopping&carnival=fun&art=painting&val=value');
  $uri->query_delete_keys_starting_with('car');
  ok($uri !~ m/car/ && $uri !~ m/carnival/ && $uri !~ m/cart/ && $uri =~ m/art=painting/ && $uri =~ m/val=value/, 'Delete values starting with a string');
  say $uri if $verbose;
}
