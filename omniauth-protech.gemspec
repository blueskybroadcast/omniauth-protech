# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'omniauth-protech/version'

Gem::Specification.new do |spec|
  spec.name          = 'omniauth-protech'
  spec.version       = Omniauth::Protech::VERSION
  spec.authors       = ['Blue Sky eLearn']
  spec.email         = ['support@blueskyelearn.com']
  spec.summary       = %q{Protech strategy for Omniauth.}
  spec.description   = %q{The strategy to use with Protech's Omniauth implementation.}
  spec.homepage      = "https://github.com/blueskybroadcast/omniauth-protech"
  spec.license       = 'MIT'
  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.add_dependency 'omniauth', '~> 1.0'
  spec.add_dependency 'omniauth-oauth2', '~> 1.0'
  spec.add_dependency 'rest-client'
  spec.add_dependency 'builder'
  spec.add_dependency 'nokogiri'
  spec.add_dependency 'multi_xml'
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'rubocop'
end
