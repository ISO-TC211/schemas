lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hrma/version'

Gem::Specification.new do |spec|
  spec.name          = "hrma"
  spec.version       = Hrma::VERSION
  spec.authors       = ["ISO/TC 211"]
  spec.email         = ["open.source@ribose.com"]
  spec.summary       = %q{Harmonized Resources Maintenance Agency CLI tool}
  spec.description   = %q{Command-line tool for managing ISO/TC 211 schemas manifest}
  spec.homepage      = "https://github.com/ISO-TC211/schemas"
  spec.license       = "MIT"
  
  spec.files         = Dir.glob("{bin,lib}/**/*") + %w(Gemfile README.adoc)
  spec.executables   = ["hrma"]
  spec.require_paths = ["lib"]
  
  spec.required_ruby_version = '>= 2.5.0'
  
  spec.add_dependency "thor", "~> 1.2"
  
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
end
