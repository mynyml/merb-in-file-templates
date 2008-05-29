require 'yaml'

module InFileTemplatesMixin
  class Cache #:nodoc:
    attr_accessor :controller
    def self.path
      Merb.dir_for(:config) / 'ift.cache'
    end
    def initialize(controller_name)
      self.controller = controller_name.to_s
    end
    def store(tpl_path)
      self.cache[self.controller] ||= []
      self.cache[self.controller] << tpl_path
      self.flush
    end
    alias :<< :store
    def files
      self.cache[self.controller]
    end
    def reset!
      self.cache.delete(self.controller)
      self.flush
    end
    def exists?
      !self.cache[self.controller].nil?
    end
    protected
      def cache
        @cache ||= self.load
      end
      def reload!
        @cache = nil
      end
      def load
        YAML::load_file(self.class.path) || {} rescue {}
      end
      def dump
        open(self.class.path,'w+') do |file|
          YAML::dump(self.cache,file)
        end
      end
      alias :flush :dump
  end
end
