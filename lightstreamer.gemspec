$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'lightstreamer/version'

Gem::Specification.new do |s|
  s.name        = 'lightstreamer'
  s.version     = Lightstreamer::VERSION
  s.platform    = Gem::Platform::RUBY
  s.license     = 'MIT'
  s.summary     = 'Ruby client for accessing a Lightstreamer server.'
  s.homepage    = 'https://github.com/rviney/lightstreamer'
  s.author      = 'Richard Viney'
  s.email       = 'richard.viney@gmail.com'
  s.files       = Dir['bin/lightstreamer', 'lib/**/*.rb', 'CHANGELOG.md', 'LICENSE.md', 'README.md']
  s.executables = ['lightstreamer']

  s.required_ruby_version = '>= 2.0'

  s.add_runtime_dependency 'rest-client', '~> 2.0'
  s.add_runtime_dependency 'thor', '~> 0.19'

  # Use Active Support 4 on Ruby versions prior to 2.2.2
  if RUBY_VERSION =~ /^2\.((0|1)\.|2\.(0|1)$)/
    s.add_development_dependency 'activesupport', '~> 4.2'
  else
    s.add_development_dependency 'activesupport', '~> 5.0'
  end

  s.add_development_dependency 'codeclimate-test-reporter', '~> 0.6'
  s.add_development_dependency 'factory_girl', '~> 4.7'
  s.add_development_dependency 'github-markup', '~> 1.4'
  s.add_development_dependency 'redcarpet', '~> 3.3'
  s.add_development_dependency 'rspec', '~> 3.5'
  s.add_development_dependency 'rspec-mocks', '~> 3.5'
  s.add_development_dependency 'rubocop', '~> 0.41'
  s.add_development_dependency 'yard', '~> 0.9'
end
