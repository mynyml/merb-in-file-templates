require 'fileutils'
begin
  require 'rubygems'
  require 'ruby-debug'
rescue
  #pass
end
require File.dirname(__FILE__) + '/spec_helper'

describe "In-file templates" do

  before(:all) do
    Merb.root = File.dirname(__FILE__) / '..' / 'root'
    Merb.push_path(:view,       Merb.root / 'views', '**/*.rb')
    Merb.push_path(:config,     Merb.root / 'config')
    Merb.push_path(:public,     Merb.root / 'public')
    Merb.push_path(:stylesheets, Merb.dir_for(:public) / "stylesheets", nil)
    Merb.push_path(:javascripts, Merb.dir_for(:public) / "javascripts", nil)
    #-----
    FileUtils.mkdir(Merb.dir_for(:config)) unless File.exist?(Merb.dir_for(:config))
    # --------- Fixtures
    class Controller1 < Merb::Controller
      provides :html, :xml
      def index; render; end
      def show;  render_from_file("foo", __FILE__); end
    end
    class Controller2 < Merb::Controller
      provides :html, :xml
      def index; render; end
    end
    require @controller3_file = File.dirname(__FILE__) / 'controller3.rb'
    # ---------- Views
    # (see end of file for rest of views)
    dir = Merb.dir_for(:view) / 'controller1'
    FileUtils.mkdir_p(dir)
    open(dir / 'static.html.erb','w+') {|file| file.write("=^.^=\n") }
  end

  before(:each) do
    Merb::Config[:reload_templates] = true
    Merb::Template::METHOD_LIST.clear #reset inline templates cache
    Controller1._template_roots = nil
    Controller2._template_roots = nil
    Controller3._template_roots = nil
    @controller1 = Controller1.new(fake_request)
    @controller2 = Controller2.new(fake_request)
    @controller3 = Controller3.new(fake_request)
    @controller  = @controller1 #synonym
    clean_tpl_files(@controller1)
    clean_tpl_files(@controller2)
    clean_tpl_files(@controller3)
  end

  after(:all) do
    clean_tpl_files(@controller1)
    clean_tpl_files(@controller2)
    clean_tpl_files(@controller3)
    #Dir[Merb.root / '*'].each {|e| FileUtils::DryRun.rm_rf(e) }
    Dir[Merb.root / '*'].each {|e| FileUtils.rm_rf(e) }
  end

  def clean_tpl_files(controller)
    controller.send(:ift_garbage_collect!)
  end

  it "should be integrated with render" do
    @controller.render(:index).strip.should == "1stctrl-index"
  end

  it "should be callable from within a controller action" do
    @controller._dispatch(:show)
    @controller.body.strip.should == "bar"
    @controller._dispatch(:index)
    @controller.body.strip.should == "1stctrl-index"
  end

  it "should be integrated with display" do
    obj = Object.new; def obj.to_html; '<b>a</b>'; end
    @controller.action_name = 'fu'
    @controller.display(obj).strip.should == '<b>a</b>'
    @controller.display(obj,:index).strip.should == '1stctrl-index'
  end

  it "should parse template engine code" do
    @controller.render(:dynamic).strip.should == "dynamic str"
  end

  it "should reload templates when code reloading is on" do
    Merb::Config[:reload_templates] = true
    @controller.render(:index).strip.should == "1stctrl-index"
    @controller.stub!(:ift_parse).and_return({'controller1/index.html.erb' => 'foobar'})
    @controller.render(:index).strip.should == 'foobar'
  end

  it "should not reload templates when code reloading is off" do
    Merb::Config[:reload_templates] = false
    @controller.render(:index).strip.should == "1stctrl-index"
    @controller.stub!(:ift_parse).and_return({'controller1/index.html.erb' => 'foobar'})
    @controller.render(:index).strip.should == '1stctrl-index'
    Merb::Config[:reload_templates] = true
    @controller.render(:index).strip.should == 'foobar'
  end

  it "should obey template content types (1)" do
    @controller.content_type(:xml)
    @controller.render(:index).strip.should == '<x>ml</x>'
  end

  it "should obey template content types (2)" do
    @controller.content_type(:html)
    @controller.render(:index).strip.should == '1stctrl-index'
  end

  it "should look for templates in file where #render is called" do
    @controller3._dispatch(:index)
    @controller3.body.strip.should == "3rdctrl-index"
  end

  it "should not get confused with many controllers in different files" do
    @controller1._dispatch(:index)
    @controller1.body.strip.should == "1stctrl-index"
    @controller3._dispatch(:index)
    @controller3.body.strip.should == "3rdctrl-index"
  end

  it "should not get confused with many controllers in the same file" do
    @controller1.render(:index).strip.should == '1stctrl-index'
    @controller2.render(:index).strip.should == '2ndctrl-index'
  end

  it "should create cache file if it doesn't exist" do
    path  = InFileTemplatesMixin::Cache.path
    cache = File.exist?(path) ? (YAML::load_file(path) || {}) : {}
    FileUtils.rm(path) if File.exist?(path)
    File.file?(path).should be_false
    @controller.render(:index).strip.should == '1stctrl-index'
    File.file?(path).should be_true
    YAML::load_file(path).should_not be_false #false when not proper yaml
  end

  it "should respect changes to config options" do
    view_root = Merb.root / 'tmp' / 'ift' / 'views'
    css_root  = Merb.dir_for(:stylesheets) / 'ift'
    js_root   = Merb.dir_for(:javascripts) / 'ift'
    #-----
    Merb::Plugins.config[:in_file_templates] = {
      :view_root        => view_root,
      :stylesheets_root => css_root,
      :javascripts_root => js_root
    }
    #-----
    @controller.render(:index)
    #-----
    view = view_root / @controller._template_location('') / 'index.html.erb'
    css  = css_root  / 'app.css'
    js   = js_root   / 'app.js'
    #-----
    File.exist?(view).should be_true
    File.exist?(css).should be_true
    File.exist?(js).should be_true
  end

  it "should respect changes to template location" do
    def @controller._template_location(context, type=nil, controller=controller_name)
      "#{controller}.#{action_name}.#{type}"
    end
    @controller.stub!(:ift_parse).and_return({'controller1.index.html.erb' => '=0.0='})
    #-----
    @controller._dispatch(:index)
    @controller.body.strip.should == "=0.0="
  end

  it "should ignore commented out templates" do
    lambda {
      @controller.render(:commented_out)
    }.should raise_error(Merb::ControllerExceptions::TemplateNotFound)
  end

  it "should guess template path prefix when not explicitly specified" do
    @controller.render(:onlyname).strip.should include('Defaults')
  end

  it "should render layouts" do
    @controller.render(:index, :layout => :custom).strip.should == "hd\n1stctrl-index\nft"
  end

  it "should render stylesheets" do
    @controller.render(:index)
    File.exist?(@controller.ift_dir_for(:stylesheets) / 'app.css').should be_true
  end

  it "should render javascript" do
    @controller.render(:index)
    File.exist?(@controller.ift_dir_for(:javascripts) / 'app.js').should be_true
  end

  describe "#render_from_file" do

    it "should read the template data from the file it is called from" do
      @controller.render_from_file(:foo).strip.should == "bar"
      @controller.render_from_file('controller1/index.html.erb').strip.should == "1stctrl-index"
    end

    it "should read template's data from provided file" do
      @controller.render_from_file(:foo, @controller3_file).strip.should == "fou"
    end

    it "should raise an error when it cannot find the template" do
      lambda {
        @controller.render_from_file(:baz)
      }.should raise_error(Merb::ControllerExceptions::TemplateNotFound)
    end

    it "should be able to find templates based on action name" do
      @controller.action_name = 'foo'
      @controller.render_from_file.strip.should == "bar"
    end
  end

  # For the purposes of this plugin, static templates refer to templates
  # defined in external files (the regular way), as opposed to those
  # dynamically generated form in-file templates.
  describe "cohabiting with static templates" do

    it "should be able to render from both in-file template and static template" do
      @controller.render(:index).strip.should == '1stctrl-index'
      @controller.render(:static).strip.should == '=^.^='
    end

    it "should not modify static templates that are already in view directories" do
      static = (
        @controller._template_root /
        @controller._template_location('') /
        'static.html.erb'
      )
      File.file?(static).should be_true
      file_prev = File.new(static)
      @controller.render(:index).strip.should == '1stctrl-index'
      File.file?(static).should be_true
      file_prev.read.should == File.new(static).read
    end

    it "should not overwrite a static template with an in-file template" do
      # views/controller1/ contains a file called static.html.erb
      @controller.stub!(:ift_parse).and_return({'static.html.erb' => '=0.0='})
      @controller.render(:static).strip.should == '=^.^='
    end

    it "should give precedence to static templates" do
      # views/controller1/ contains a file called static.html.erb
      @controller.stub!(:ift_parse).and_return({'static.html.erb' => '=0.0='})
      @controller.render(:static).strip.should == '=^.^='
    end
  end

  describe "rake tasks" do
    #setup for rake task specs thanks to
    #http://blog.nicksieger.com/articles/2007/06/11/test-your-rake-tasks

    before(:all) { require 'rake' }

    before(:each) do
      @rake = Rake::Application.new
      Rake.application = @rake
      load 'lib/merb-in-file-templates/merbtasks.rb'
    end

    after(:each) do
      Rake.application = nil
    end

    it "should garbage collect the dynamic views" do
      @controller1._dispatch(:index)
      @controller3._dispatch(:index)
      File.file?(@controller1.ift_path_for('foo'             )).should be_true
      File.file?(@controller1.ift_path_for('index.xml.erb'   )).should be_true
      File.file?(@controller1.ift_path_for('index.html.erb'  )).should be_true
      File.file?(@controller1.ift_path_for('dynamic.html.erb')).should be_true
      File.file?(@controller3.ift_path_for('foo'             )).should be_true
      File.file?(@controller3.ift_path_for('index.html.erb'  )).should be_true
      File.file?(@controller3.ift_path_for('qwerty.xml.haml' )).should be_true
      @rake['in_file_templates:clean'].invoke
      File.file?(@controller1.ift_path_for('foo'             )).should be_false
      File.file?(@controller1.ift_path_for('index.xml.erb'   )).should be_false
      File.file?(@controller1.ift_path_for('index.html.erb'  )).should be_false
      File.file?(@controller1.ift_path_for('dynamic.html.erb')).should be_false
      File.file?(@controller3.ift_path_for('foo'             )).should be_false
      File.file?(@controller3.ift_path_for('index.html.erb'  )).should be_false
      File.file?(@controller3.ift_path_for('qwerty.xml.haml' )).should be_false
    end

    it "should raise warn that cache might be corrupted if a listed file doesn't exist" do
      @controller.render(:index).strip.should == '1stctrl-index'
      @controller.instance_variable_get(:@cache).store(@controller.ift_path_for('rogue.php'))
      lambda {
        @rake['in_file_templates:clean'].invoke
      }.should raise_error
    end
  end
end

__END__
@@ foo
bar

@@ layout/custom.html.erb
hd
<%= catch_content(:for_layout).strip %>
ft

@@ controller1/index.html.erb
1stctrl-index

@@ controller2/index.html.erb
2ndctrl-index

@@ controller1/dynamic.html.erb
<%= "dynamic str" %>

@@ controller1/index.xml.erb
<x>ml</x>

#@@ controller1/commented_out
should not be parsed

@@ onlyname.html.erb
Defaults to current controller (the one #render is called from) when no path
prefix is specified. Useful when there's a single controller in the file, but
be careful about creating conflicts when there's multiple controllers and they
have templates of the same name

@@ public/stylesheets/app.css
a { color: red; }

@@ javascripts/app.js
var x = 'x'
