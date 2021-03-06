# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'volt/watch/version'

Gem::Specification.new do |spec|
  spec.name          = 'volt-watch'
  spec.version       = Volt::Watch::VERSION
  spec.authors       = ['Colin Gunn']
  spec.email         = ['colgunn@icloud.com']
  spec.summary       = %q{Helper plugin for to provide easy reactivity bindings in Volt models and controllers.}
  spec.homepage      = 'https://github.com/balmoral/volt-watch'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']
end
