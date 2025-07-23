requires 'perl' => '5.036000';
requires 'Plack';
requires 'Module::Loaded';
requires 'Router::Boom';

# In core but list anyway
requires 'Digest::MD5';
requires 'List::Util';

# Optional
recommends 'Config::Any';
recommends 'JSON::MaybeXS';
recommends 'URI::Fast';
recommends 'Template';

# For Testing
on 'test' => sub {
    requires 'Test::More', '0.98';
};
