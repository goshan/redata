# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redata/version'

Gem::Specification.new do |spec|
  spec.name          = "redata"
  spec.version       = Redata::VERSION
  spec.authors       = ["goshan"]
  spec.email         = ["goshan.hanqiu@gmail.com"]

  spec.summary       = %q{a AWS Redshift data process controller}
  spec.description   = %q{Controll data process by sub query and easy command line}
  spec.homepage      = "https://github.com/goshan/redata"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.executables   = ["redata", "adjust", "notice"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency "json", "~> 2.0"
  spec.add_runtime_dependency "colorize", "~> 0.8"
  spec.add_runtime_dependency "aws-sdk", "~> 2.6"
  spec.add_runtime_dependency "timezone", "~> 1.2"
  spec.add_runtime_dependency "slack-api", "~> 1.2"
end
