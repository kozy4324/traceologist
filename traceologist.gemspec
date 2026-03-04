# frozen_string_literal: true

require_relative "lib/traceologist/version"

Gem::Specification.new do |spec|
  spec.name = "traceologist"
  spec.version = Traceologist::VERSION
  spec.authors = ["Koji NAKAMURA"]
  spec.email = ["kozy4324@gmail.com"]

  spec.summary = "Trace Ruby method call sequences with arguments and return values."
  spec.description = <<~DESC
    Traceologist wraps a block of Ruby code with TracePoint and returns a
    structured, human-readable log of every method call, its arguments, and
    its return value. Useful for debugging and understanding runtime behavior.
  DESC
  spec.homepage = "https://github.com/kozy4324/traceologist"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
