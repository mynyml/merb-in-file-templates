if defined?(Merb::Plugins)

  require 'merb-in-file-templates/cache'
  require 'merb-in-file-templates/in_file_templates_mixin'

  # Config options
  # This plugin will respect Merb::Config[:reload_templates]. This means that
  # if set to true, templates will be rebuilt every time #render is called.
  Merb::Plugins.config[:in_file_templates] = {
    :view_root        => nil,
    :stylesheets_root => nil,
    :javascripts_root => nil,
    :garbage_collect  => true #unused
  }

  Merb::BootLoader.after_app_loads do
    Merb::Controller.class_eval do
      include InFileTemplatesMixin
    end
  end

  Merb::Plugins.add_rakefiles "merb-in-file-templates/merbtasks"
end
