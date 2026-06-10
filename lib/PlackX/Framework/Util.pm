use v5.36;
package PlackX::Framework::Util {
  use MIME::Base64 ();
  use Digest::MD5 ();
  use Exporter qw(import);

  # MD5 digests, url-encoded
  sub md5_ubase64      ($str) { Digest::MD5::md5_base64($str) =~ tr|+/=|-_|dr }
  sub md5_ushort ($str, $len) { substr(md5_ubase64($str),0,$len)              }

  # Sleep for a fractional number of seconds
  sub minisleep    ($seconds) { select(undef, undef, undef, $seconds)         }

  # Module util (inspired by Module::Loaded)
  sub name_to_pm         ($name) { $name =~ s|::|/|gr . '.pm'         }
  sub mark_module_loaded ($name) { $INC{name_to_pm($name)} = 'Marked' }
  sub is_module_loaded   ($name) { exists $INC{name_to_pm($name)}     }
  sub is_module_ok       ($name) { defined $INC{name_to_pm($name)}    }
  sub is_module_broken   ($name) { is_module_loaded($name) and !is_module_ok($name) }

  # JSON and Base 64
  sub json_codec () {
    require JSON::MaybeXS;
    state $json_codec = JSON::MaybeXS->new(utf8 => 1);
    $json_codec;
  }

  sub encode_json ($dat) { json_codec->encode($dat) }
  sub decode_json ($str) { json_codec->decode($str) }
  sub encode_ju64 ($dat) { b64_to_u64(MIME::Base64::encode(encode_json($dat))) }
  sub decode_ju64 ($str) { decode_json(MIME::Base64::decode(u64_to_b64($str))) }
  sub b64_to_u64  ($str) { $str =~ tr`+/=\n`-_`dr }
  sub u64_to_b64  ($str) { $str =~ tr`-_`+/`r     }

  our @EXPORT = grep { $_ ne 'import' and $_ =~ m/^[a-z]/ } keys %PlackX::Framework::Util::;
}

1;

=pod

=head1 NAME

PlackX::Framework::Util - Utilities for PlackX::Framework


=head1 SYNOPSIS

    use PlackX::Framework::Util;
    ...


=head1 EXPORTS

All by default, or only the ones specified.


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
