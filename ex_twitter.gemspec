lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.add_dependency 'twitter'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'parallel'

  spec.add_development_dependency 'bundler'

  spec.authors = ['Shinohara Teruki']
  spec.description = %q(Add auto paginate feature to Twitter gem.)
  spec.email = %w[ts_3156@yahoo.co.jp]
  spec.files = %w[LICENSE.md README.md Rakefile ex_twitter.gemspec]
  spec.files += Dir.glob('lib/**/*.rb')
  spec.files += Dir.glob('spec/**/*')
  spec.homepage = 'http://github.com/ts-3156/ex-twitter/'
  spec.licenses = %w[MIT]
  spec.name = 'ex_twitter'
  spec.require_paths = %w[lib]
  spec.summary = spec.description
  spec.test_files = Dir.glob('spec/**/*')
  spec.version = '0.0.4'
end
