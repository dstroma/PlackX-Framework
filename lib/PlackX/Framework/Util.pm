use v5.36;
package PlackX::Framework::Util {
  use PlackX::Framework::Exporter qw(import);

  # MD5 digests, url-encoded
  use Digest::MD5 ();
  sub md5_ubase64      ($str) { Digest::MD5::md5_base64($str) =~ tr|+/=|-_|dr }
  sub md5_ushort ($str, $len) { substr(md5_ubase64($str),0,$len)              }

  # Sleep for a fractional number of seconds
  sub minisleep    ($seconds) { select(undef, undef, undef, $seconds)         }

  # Module util (inspired by Module::Loaded)
  sub name_to_pm         ($name) { $name =~ s|::|/|gr . '.pm'        }
  sub mark_module_loaded ($name) { $INC{name_to_pm($name)} = 'DUMMY' }
  sub is_module_loaded   ($name) { exists $INC{name_to_pm($name)}    }
  sub is_module_broken   ($name) {
    my $pm = name_to_pm($name);
    exists $INC{$pm} and !defined $INC{$pm}
  }
}

1;

=pod

=head1 NAME

PlackX::Framework::Util - Utilities for PXF


=head1 SYNOPSIS

    use PlackX::Framework::Util qw(md5_urlshort minisleep);
    ...


=head1 EXPORTS

None by default.


=head1 FUNCTIONS

=over 4

=item md5_urlbase64($string)

Returns the md5 of $string in base64, replacing url-unsafe characters with
safe ones.

=item md5_urlshort($string, $len)

Returns a shortened url-safe base64 md5 of $string.

=item minisleep(seconds)

Sleep for a fractional number of seconds.

=back

=head1 META

For copyright and license, see PlackX::Framework.
