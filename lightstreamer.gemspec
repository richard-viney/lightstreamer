$LOAD_PATH.push File.expand_path('../lib', __FILE__)
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

  s.required_ruby_version = '>= 2.2.2'

  s.add_runtime_dependency 'excon', '~> 0.51'
  s.add_runtime_dependency 'thor', '~> 0.19'

  s.add_development_dependency 'codeclimate-test-reporter', '~> 1.0'
  s.add_development_dependency 'factory_bot', '~> 4.8'
  s.add_development_dependency 'github-markup', '~> 2.0'
  s.add_development_dependency 'redcarpet', '~> 3.3'
  s.add_development_dependency 'rspec', '~> 3.6'
  s.add_development_dependency 'rspec-mocks', '~> 3.6'
  s.add_development_dependency 'rubocop', '~> 0.52'
  s.add_development_dependency 'rubocop-rspec', '~> 1.21'
  s.add_development_dependency 'simplecov', '~> 0.12'
  s.add_development_dependency 'yard', '~> 0.9'
end
