#!perl
use v5.36;
use Test::More;

do_tests();
done_testing();

#######################################################################

sub do_tests {

  my $class = 'PXF::Util';
  use_ok($class);

  # Sleep
  {
    require Time::HiRes;
    for (my $interval = 0.1; $interval < 1; $interval *= 2) {
      my $t1 = Time::HiRes::time();
      PXF::Util::minisleep($interval);
      my $t2 = Time::HiRes::time();
      my $el = $t2 - $t1;
      ok(
        ($interval*0.85 < $el < $interval*1.15 and $interval-0.1 < $el < $interval+0.1),
        "Sleep for $interval seconds is accurate within 15% and 0.1s"
      );
    }
  }

  # MD5
  {
    my %known = (
      'b' => 'kutf_uauL-w61xx3dTFXjw',
      'abcdefghijklmnopqrstuvwxyz' => 'w_zT12GS5AB9-0lsymfhOw',
    );

    my %known_incorrect = (
      'b' => 'kutf-uauL_w61xx3dTFXjw',
      'abcdefghijklmnopqrstuvwxyz' => 'w_zT12GS5AB9_0lsymfhOw',
      'random' => 'random',
    );

    foreach my $key (keys %known) {
      is(
        PXF::Util::md5_ubase64($key) => $known{$key},
        'url-encoded MD5 is correct'
      );

      for my $len (1..16) {
        is(
          PXF::Util::md5_ushort($key,$len) => substr($known{$key},0,$len),
          "url-encoded MD5 shortened to $len is correct"
        );
      }
    }

    foreach my $key (keys %known_incorrect) {
      isnt(
        PXF::Util::md5_ubase64($key) => $known_incorrect{$key},
        'Known incorrect md5 is incorrect'
      );
    }
  }

  # Modules
  {
    require Plack::Util;
    ok(
      PXF::Util::is_module_loaded('Plack::Util'),
      'Module is loaded'
    );

    ok(
      (not PXF::Util::is_module_broken('Plack::Util')),
      'Module is not broken'
    );
    is(
      PXF::Util::name_to_pm('Plack::Util') => 'Plack/Util.pm',
      'Module name to PM checks'
    );

    eval {
      local @INC;
      push @INC, './t/tlib';
      require BrokenTest;
      1;
    };
    ok(
      (PXF::Util::is_module_broken('BrokenTest')),
      'BrokenTest module is broken'
    );
  }

}
