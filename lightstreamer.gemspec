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

  s.required_ruby_version = '>= 2.4.0'

  s.add_runtime_dependency 'excon', '~> 0.66'
  s.add_runtime_dependency 'thor', '~> 0.20'

  s.add_development_dependency 'factory_bot', '~> 5.0'
  s.add_development_dependency 'github-markup', '~> 3.0'
  s.add_development_dependency 'redcarpet', '~> 3.3'
  s.add_development_dependency 'rspec', '~> 3.8'
  s.add_development_dependency 'rspec-mocks', '~> 3.8'
  s.add_development_dependency 'rubocop', '~> 0.74'
  s.add_development_dependency 'rubocop-performance', '~> 1.4'
  s.add_development_dependency 'rubocop-rspec', '~> 1.35'
  s.add_development_dependency 'simplecov', '~> 0.17'
  s.add_development_dependency 'yard', '~> 0.9'
end
