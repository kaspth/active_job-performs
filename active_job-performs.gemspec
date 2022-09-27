# frozen_string_literal: true

require_relative "lib/active_job/performs/version"

Gem::Specification.new do |spec|
  spec.name = "active_job-performs"
  spec.version = ActiveJob::Performs::VERSION
  spec.authors = ["Kasper Timm Hansen"]
  spec.email = ["hey@kaspth.com"]

  spec.summary = "ActiveJob::Performs is a lightweight DSL for setting up jobs by convention."
  spec.homepage = "https://github.com/kaspth/active_job-performs"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "activejob", ">= 6.1"
end
