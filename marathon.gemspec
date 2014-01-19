# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'marathon/version'

Gem::Specification.new do |spec|
  spec.authors     = ['Chris Maddox']
  spec.date        = '2013-10-02'
  spec.description = 'Managing long running processes.'
  spec.email       = 'tyre77@gmail.com'
  spec.files       = %w(LICENSE.md README.md marathon.gemspec)
  spec.files      += Dir.glob('lib/**/*.rb')
  spec.files      += Dir.glob('spec/**/*')
  spec.homepage    = 'http://rubygems.org/gems/marathon'
  spec.licenses    = ['MIT']
  spec.name        = 'marathon'
  spec.summary     = 'Managing long running processes.'
  spec.test_files += Dir.glob('spec/**/*')
  spec.version     = Marathon::Version.to_s
end
