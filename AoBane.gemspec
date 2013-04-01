# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'AoBane/version'

Gem::Specification.new do |spec|
  spec.name          = "AoBane"
  spec.version       = AoBane::VERSION
  spec.authors       = ["set"]
  spec.email         = ["set.minami@gmail.com"]
  spec.description   = %q{AoBane The Markdown engine powered by BlueFeather}
  spec.summary       = %q{You can write colored font without css and special characters with simple way.}
  spec.homepage      = "https://github.com/setminami/AoBane"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "math_ml"
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
