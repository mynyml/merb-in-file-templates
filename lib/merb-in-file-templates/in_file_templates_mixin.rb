require 'fileutils'

# The in-file-templates mixin allows defining view templates inside controller
# files. Especially useful for --very-flat apps that have few/small view code,
# and for rapid prototyping.
#
# Templates are defined at the end of the controller file, following the
# __END__ keyword (__END__ must be placed at the very beginning of the line,
# with nothing following it). Each template is consists of its name, marked by
# @@ (@@ must also be placed at the very beginning of the line), followed be
# the template's content.
#
# Template names follow the same rules as regular merb templates:
#
#   name.mime_type.templating_engine:
#     index.html.erb, edit.html.haml, show.xml.bilder, etc
#
# ==== Examples
#   class Application < Merb::Controller; end
#   class Products < Application
#     def index
#       @products = Product.all
#       render
#     end
#     def show
#       @product = Product[params[:id]]
#       render
#     end
#   end
#
#   __END__
#   @@ index.html.erb
#   <h1>Product List</h1>
#   <ul>
#     <% for product in @products -%>
#       <li><%= product.name %></li>
#     <% end -%>
#   </ul>
#
#   @@ show.html.erb
#   <h1><%= @product.name %></h1>
#
# ==== Notes
# Most methods are prefixed with ift_ (In File Templates). This is simply to
# avoid naming conflicts with controller methods.
module InFileTemplatesMixin

  # When mixin is included in controller, define aliases to wrap #render and
  # #display
  #
  # ==== Parameters
  # base<Module>:: Module that is including InFileTemplatesMixin (probably a controller)
  #
  # ==== Notes
  # http://yehudakatz.com/2008/05/22/the-greatest-thing-since-sliced-merb/
  # "We consider cases of people using alias_method_chain on Merb to be a bug in
  # Merb, and try to find ways to expose enough functionality so it will not be
  # required."
  # So could this code be written otherwise, or is it an exception to the above
  # rule? what are the alternatives?
  #_
  # @public
  def self.included(base)
    base.send(:alias_method, :render_without_in_file_templates, :render)
    base.send(:alias_method, :render, :render_with_in_file_templates)
    base.send(:alias_method, :display_without_in_file_templates, :display)
    base.send(:alias_method, :display, :display_with_in_file_templates)
  end

  # Wrap #render to gather template data from caller's file and trigger
  # template build process.
  #
  # ==== Parameters
  # Same as Merb::RenderMixin#render
  #
  # ==== Returns
  # Same as Merb::RenderMixin#render
  #
  # ==== Raises
  # Same as Merb::RenderMixin#render
  #
  # ==== Alternatives
  # Same as Merb::RenderMixin#render
  #_
  # @public
  def render_with_in_file_templates(*args) #:nodoc:
    ift_build!((@ift_caller ||= caller).first.split(':').first)
    render_without_in_file_templates(*args)
  end

  # Overwrite display and set caller so that #render (called internally by
  # #display) knows what file to fetch template data from.
  #
  # ==== Parameters
  # Same as Merb::RenderMixin#display
  #
  # ==== Returns
  # Same as Merb::RenderMixin#display
  #
  # ==== Raises
  # Same as Merb::RenderMixin#display
  #
  # ==== Alternatives
  # Same as Merb::RenderMixin#display
  # -----
  # @public
  def display_with_in_file_templates(*args) #:nodoc:
    @ift_caller = caller
    display_without_in_file_templates(*args)
  end

  # Render in-file template in a very basic fashion; only fetches the template
  # as a string, without having it go through the templating system (which
  # includes the templating engines). The method then is equivalent to directly
  # returning a string from the action method.
  #
  # ==== Examples
  #   def index
  #     'hello world'
  #   end
  #
  # is equivalent to:
  #
  #   def index
  #     render_from_file(:index)
  #   end
  #   #...
  #   __END__
  #   @@ index
  #   hello world
  #
  # You can also use a templating engine manually:
  #
  #   def index
  #     @name = 'world'
  #     Erubis::Eruby.new(render_from_file(:new)).result(binding)
  #   end
  #   #...
  #   __END__
  #   @@ index
  #   hello <%= @name %>
  #
  # ==== Parameters
  # context<~to_s, nil>::
  #   Name of the template to fetch. Defaults to action name
  # file<String, nil>::
  #   Path to a file in which to fetch the template data. Default is file this
  #   method has been called from
  #
  # ==== Returns
  # String:: Raw template
  #
  # ==== Raises
  # TemplateNotFound:: There is no template in the specified file.
  #_
  # @public
  def render_from_file(context=action_name, file=nil)
    file ||= caller.first.split(':').first
    data = IO.read(file).split('__END__').last
    ift_parse(data)[context.to_s] or raise(Merb::Controller::TemplateNotFound, "Template #{context} not found in #{File.expand_path(file)}")
  end

  # Builds templates from in-file data so that they can be picked up by merb's
  # templating system. Building includes parsing the data to extract the
  # templates and then writing them to files.
  #
  # Will skip rebuilding process if Merb::Config[:reload_templates] is false
  #
  # ==== Parameters
  # file<String>::
  #   Path to a file in which to fetch the template data.
  #_
  # @semipublic
  def ift_build!(file)
    # write templates to view files if they haven't been already been
    # written, or always if :reload_templates config option is true
    return unless !ift_built? || Merb::Config[:reload_templates] 

    data = IO.read(file).split('__END__').last
    templates = ift_parse(data)

    self.ift_set_template_roots!
    self.ift_garbage_collect!

    templates.each do |name,data|
      path = ift_path_for(name)
      unless File.exist?(path) #don't overwrite externaly defined templates
        self.ift_write_template(path, data)
        @cache << path
      end
    end
  end

  # Construct path (including filename) for given template name.
  # Template can be a view, stylesheet or javascript file.
  #
  # ==== Parameters
  # name<String>:: Template name
  #
  # ==== Returns
  # String:: Path to template
  #
  # ==== Examples
  #   # given @@ products/foo.html.erb
  #   ift_path_for('foo.html.erb') #=> /merb.root/views/products/foo.html.erb
  #
  #   # given @@ bar.html.erb
  #   # and current controller is Products
  #   ift_path_for('bar.html.erb') #=> /merb.root/views/products/bar.html.erb
  #
  #   # given @@ public/stylesheet/app.css
  #   ift_path_for('app.css') #=> /merb.root/public/stylesheets/app.css
  #_
  # @semipublic
  def ift_path_for(name)
    name =
      if ift_stylesheet?(name)
        self.ift_dir_for(:stylesheets) / File.basename(name)
      elsif ift_javascript?(name)
        self.ift_dir_for(:javascripts) / File.basename(name)
      else
        name = ift_template_dir / name unless name.include?('/') #add path prefix if omitted
        self.ift_dir_for(:view) / name
      end
    File.expand_path(name)
  end

  # Get in-file template directory for a type. Equivalent to Merb.dir_for,
  # but taking config options for template paths into consideration.
  #
  # ==== Parameters
  # type<Symbol>::
  #   The type of path to retrieve directory for, e.g. :view. Accepted types
  #   are :view, :stylesheets and :javascripts
  #
  # ==== Returns
  # String:: Path to the type directory
  #_
  # @public
  def ift_dir_for(type)
    case type
    when :view
      Merb::Plugins.config[:in_file_templates][:view_root] ||
      self._template_root
    when :stylesheets
      Merb::Plugins.config[:in_file_templates][:stylesheets_root] ||
      Merb.dir_for(:stylesheets)
    when :javascripts
      Merb::Plugins.config[:in_file_templates][:javascripts_root] ||
      Merb.dir_for(:javascripts)
    end
  end

  # Find out if template defines a stylesheet, based on template's name.
  #
  # ==== Parameters
  # name<String>:: Template name
  #
  # ==== Returns
  # Boolean:: True if stylesheet, false otherwise
  #
  # ==== Examples
  #   # given Merb.dir_for(:stylesheets) #=> '/merb.root/public/stylesheets'
  #   ift_stylesheet?('public/stylesheets/app.css') #=> true
  #   ift_stylesheet?('stylesheets/app.css') #=> true
  #   ift_stylesheet?('index.html.erb') #=> false
  #_
  # @semipublic
  def ift_stylesheet?(name)
    dir = File.dirname(name).chomp('.')
    dir.empty? ? false : !!(Merb.dir_for(:stylesheet) =~ /#{dir}$/)
  end

  # Find out if template defines a javascript, based on template's name.
  #
  # ==== Parameters
  # name<String>:: Template name
  #
  # ==== Returns
  # Boolean:: True if javascript, false otherwise
  #
  # ==== Examples
  #   # given Merb.dir_for(:javascript) #=> '/merb.root/public/javascripts'
  #   ift_javascript?('public/javascripts/app.js') #=> true
  #   ift_javascript?('javascripts/app.js') #=> true
  #   ift_javascript?('index.html.erb') #=> false
  #   ift_javascript?('app.js') #=> false
  #_
  # @semipublic
  def ift_javascript?(name)
    dir = File.dirname(name).chomp('.')
    dir.empty? ? false : !!(Merb.dir_for(:javascript) =~ /#{dir}$/)
  end

  # Get path to current controller's template location, relative to template
  # root (not view root).
  #
  # ==== Returns
  # String:: relative path to template location
  #_
  # @semipublic
  def ift_template_dir
    File.dirname(
      self._template_location("im in ur gems, playin' wif ur templetz")
    )
  end

  # Parse given data and extract individual templates and their names.
  #
  # ==== Parameters
  # data<String>:: Raw templates data
  #
  # ==== Returns
  # Hash:: Template names (keys) and their raw content (values)
  #
  # ==== Examples
  #   @@ template_name
  #   content here
  #
  #   @@ index.html.erb
  #   the two @ signs must be at the beginning of the line
  #
  #   @@ template names can even include spaces
  #   pretty unconventional though
  #_
  # @semipublic
  def ift_parse(data)
    templates, current, ignore = {}, nil, false
    data.each_line do |line|
      #(templates[current = $2], ignore = '', $1=='#') and next if line =~ /^(\#)*@@\s*(.*)/
      #templates[current] << line if current unless ignore
      if line =~ /^(\#)*@@\s*(.*)/
        #ignore = ($1 == '#') #skip commented out templates
        #next if ignore
        #current = $2
        #templates[current] = ''
        ignore = ($1 == '#') and next #skip commented out templates
        templates[current = $2] = ''
      elsif ignore
        next
      elsif current
        templates[current] << line
      end
    end
    templates
  end

  # Rid template directory of all dynamically created files (those created
  # through #ift_build!).
  #_
  # @semipublic
  def ift_garbage_collect!
    ift_init_cache
    if @cache.exists?
      @cache.files.each do |file|
        file.chomp!
        FileUtils.rm(file) if File.exist?(file)
      end
      @cache.reset!
    end
  end

  protected

  # Add custom template root to controller's #_template_roots, based on config
  # option. If option isn't set, template_roots stay unchanged.
  #_
  # @private
  def ift_set_template_roots!
    if root = Merb::Plugins.config[:in_file_templates][:view_root]
      self.class._template_roots.unshift([root, :_template_location])
    end
  end

  # Write template data to a file. 
  #
  # ==== Parameters
  # file<String>:: Path name to file in which to store template data.
  # data<String>:: Template data
  #_
  # @private
  def ift_write_template(file, data)
    dir = File.dirname(file)
    FileUtils.mkdir_p(dir) unless File.directory?(dir)
    open(file, 'w+') {|f| f.write(data) }
  end

  # Determine whether templates have already been built.
  #
  # ==== Returns
  # Boolean::
  #   True if templates have been built for this controller, false otherwise
  #_
  # @private
  def ift_built?
    ift_init_cache
    @cache.exists?
  end

  # Initialize cache.
  # Because the cache depends on controller specific information, it has to be
  # set while execution is in actual controller (as opposed to parent).
  #_
  # @private
  def ift_init_cache
    #@cache ||= Cache.new(self.controller_name)
    @cache = Cache.new(self.controller_name)
  end

  # unused; optional garbage collection not yet implemented.
  #_
  # @private
  def ift_garbage_collect?
    !!Merb::Plugins.config[:in_file_templates][:garbage_collect]
  end
end
