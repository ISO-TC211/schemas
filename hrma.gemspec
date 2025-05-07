require_relative 'lib/hrma/version'

Gem::Specification.new do |spec|
  spec.name          = "hrma"
  spec.version       = Hrma::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]
  spec.summary       = %q{Management utility for the ISO/TC 211 Harmonized Resources Maintenance Agency}
  spec.description   = %q{Command-line tool for managing ISO/TC 211 Harmonized Resources Maintenance Agency repositories.}
  spec.homepage      = "https://www.ribose.com/"
  spec.license       = "MIT"

  spec.files         = Dir.glob("{bin,lib}/**/*") + %w(Gemfile README.adoc)
  spec.executables   = ["hrma"]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 3.0.0'

  spec.add_dependency "thor", "~> 1.2"
  spec.add_dependency "rake", "~> 13.0"
  spec.add_dependency "ruby-progressbar", "~> 1.13"
  spec.add_dependency "fractor", "~> 0.1"
end
