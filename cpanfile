requires 'perl' => '5.036000';
requires 'Plack';
requires 'Module::Loaded';
requires 'Role::Tiny';
requires 'Router::Boom';
requires 'URI::Fast';

# In core but list anyway
requires 'Digest::MD5';
requires 'List::Util';
requires 'Scalar::Util';

# Optional
recommends 'Config::Any';
recommends 'JSON::MaybeXS';
recommends 'Template';

# For Testing
on 'test' => sub {
    requires 'Test::More', '0.98';
};
