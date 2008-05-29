$TESTING=true
$:.push File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'merb-core'
require 'merb-in-file-templates'
require 'spec'

Merb.start :environment => 'test'

Spec::Runner.configure do |config|
  config.include Merb::Test::RequestHelper  
end
