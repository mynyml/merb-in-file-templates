require 'rubygems'
require 'rake/gempackagetask'
require 'rubygems/specification'
require 'date'

PLUGIN = "merb-in-file-templates"
NAME = "merb-in-file-templates"
GEM_VERSION = "0.3.1"
AUTHOR = "Martin Aumont"
EMAIL = "mynyml@gmail.com"
HOMEPAGE = "http://github.com/mynyml/"
SUMMARY = "Merb plugin that allows templates (views, css, js) to be defined in the same file as the controller"

spec = Gem::Specification.new do |s|
  s.name = NAME
  s.version = GEM_VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README", "LICENSE", 'TODO']
  s.summary = SUMMARY
  s.description = s.summary
  s.author = AUTHOR
  s.email = EMAIL
  s.homepage = HOMEPAGE
  s.add_dependency('merb', '>= 0.9.4')
  s.require_path = 'lib'
  #s.autorequire = PLUGIN
  s.files = %w(LICENSE README Rakefile TODO) + Dir.glob("{lib,spec}/**/*")
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "install the plugin locally"
task :install => [:package] do
  sh %{sudo gem install pkg/#{NAME}-#{GEM_VERSION} --no-update-sources}
end

desc "create a gemspec file"
task :make_spec do
  File.open("#{NAME}.gemspec", "w") do |file|
    file.puts spec.to_ruby
  end
end

namespace :jruby do

  desc "Run :package and install the resulting .gem with jruby"
  task :install => :package do
    sh %{#{SUDO} jruby -S gem install pkg/#{NAME}-#{Merb::VERSION}.gem --no-rdoc --no-ri}
  end
  
end
