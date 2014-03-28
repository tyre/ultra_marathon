# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ultra_marathon/version'

Gem::Specification.new do |spec|
  spec.authors     = ['Chris Maddox']
  spec.date        = '2013-03-27'
  spec.description = 'Managing long running processes.'
  spec.email       = 'tyre77@gmail.com'
  spec.files       = %w(LICENSE.md README.md ultra_marathon.gemspec)
  spec.files      += Dir.glob('lib/**/*.rb')
  spec.files      += Dir.glob('spec/**/*')
  spec.homepage    = 'https://github.com/tyre/ultra_marathon'
  spec.licenses    = ['MIT']
  spec.name        = 'ultra_marathon'
  spec.summary     = 'Managing ultra long running processes.'
  spec.test_files += Dir.glob('spec/**/*')
  spec.version     = UltraMarathon::Version.to_s
end
