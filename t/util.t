#!perl
use v5.36;
use Test::More;

do_tests();
done_testing();

#######################################################################

sub do_tests {

  my $class = 'PlackX::Framework::Util';
  use_ok($class);

  # True and False
  #{
  #  ok( PlackX::Framework::Util::TRUE(),  'True is true');
  #  ok(!PlackX::Framework::Util::FALSE(), 'False is false');
  #}

  # Sleep
  {
    require Time::HiRes;
    foreach my $interval (1..9) {
      $interval *= 0.1;
      my $t1 = Time::HiRes::time();
      PlackX::Framework::Util::minisleep($interval);
      my $t2 = Time::HiRes::time();
      my $el = $t2 - $t1;
      ok(
        ($el > $interval*0.85 and $el < $interval*1.15),
        "Sleep for $interval seconds is accurate within 15%"
      );
    }
  }

  # MD5
  {
    my %known = (b => 'kutf_uauL-w61xx3dTFXjw');
    foreach my $key (keys %known) {
      is(
        PlackX::Framework::Util::md5_ubase64($key) => $known{$key},
        'url-encoded MD5 is correct'
      );

      for my $len (1..16) {
        is(
          PlackX::Framework::Util::md5_ushort($key,$len) => substr($known{$key},0,$len),
          "url-encoded MD5 shortened to $len is correct"
        );
      }
    }
  }

  # Modules
  {
    require Plack::Util;
    ok(
      PlackX::Framework::Util::is_module_loaded('Plack::Util'),
      'Module is loaded'
    );

    ok(
      (not PlackX::Framework::Util::is_module_broken('Plack::Util')),
      'Module is not broken'
    );
    is(
      PlackX::Framework::Util::name_to_pm('Plack::Util') => 'Plack/Util.pm',
      'Module name to PM checks'
    );

    eval {
      local @INC;
      push @INC, './t/tlib';
      require BrokenTest;
      1;
    };
    ok(
      (PlackX::Framework::Util::is_module_broken('BrokenTest')),
      'BrokenTest module is broken'
    );
  }

}
