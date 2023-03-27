$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'lightstreamer/version'

Gem::Specification.new do |s|
  s.name = 'lightstreamer'
  s.version = Lightstreamer::VERSION
  s.platform = Gem::Platform::RUBY
  s.license = 'MIT'
  s.summary = 'Library and command-line client for accessing a Lightstreamer server.'
  s.homepage = 'https://github.com/richard-viney/lightstreamer'
  s.author = 'Richard Viney'
  s.email = 'richard.viney@gmail.com'
  s.files = Dir['bin/lightstreamer', 'lib/**/*.rb', 'CHANGELOG.md', 'LICENSE.md', 'README.md']
  s.executables = ['lightstreamer']

  s.required_ruby_version = '>= 2.7'

  s.add_runtime_dependency 'excon', '~> 0.99'
  s.add_runtime_dependency 'thor', '~> 1.0'

  s.add_development_dependency 'factory_bot', '~> 6.2'
  s.add_development_dependency 'github-markup', '~> 4.0'
  s.add_development_dependency 'redcarpet', '~> 3.6'
  s.add_development_dependency 'rspec', '~> 3.12'
  s.add_development_dependency 'rspec-mocks', '~> 3.12'
  s.add_development_dependency 'rubocop', '~> 1.48'
  s.add_development_dependency 'rubocop-performance', '~> 1.16'
  s.add_development_dependency 'rubocop-rspec', '~> 2.19'
  s.add_development_dependency 'simplecov', '~> 0.21'
  s.add_development_dependency 'yard', '~> 0.9'
  s.metadata['rubygems_mfa_required'] = 'true'
end
