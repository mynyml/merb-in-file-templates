Gem::Specification.new do |s|
  s.name = %q{merb-in-file-templates}
  s.version = "0.3.1"

  s.specification_version = 2 if s.respond_to? :specification_version=

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Martin Aumont"]
  s.date = %q{2008-06-10}
  s.description = %q{Merb plugin that allows templates (views, css, js) to be defined in the same file as the controller}
  s.email = %q{mynyml@gmail.com}
  s.extra_rdoc_files = ["README", "LICENSE", "TODO"]
  s.files = ["LICENSE", "README", "Rakefile", "TODO", "lib/merb-in-file-templates", "lib/merb-in-file-templates/cache.rb", "lib/merb-in-file-templates/in_file_templates_mixin.rb", "lib/merb-in-file-templates/merbtasks.rb", "lib/merb-in-file-templates.rb", "spec/merb-in-file-templates_spec.rb", "spec/spec.opts", "spec/controller3.rb", "spec/spec_helper.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/mynyml/}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.1.1}
  s.summary = %q{Merb plugin that allows templates (views, css, js) to be defined in the same file as the controller}

  s.add_dependency(%q<merb>, [">= 0.9.4"])
end
