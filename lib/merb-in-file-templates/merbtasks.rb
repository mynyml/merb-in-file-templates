namespace :in_file_templates do
  desc "Remove all generated template files"
  task :clean do
    require 'fileutils'
    YAML::load_file(Merb.dir_for(:config) / 'ift.cache').values.flatten.each do |file|
      unless File.exist?(file)
        file_path = file.gsub(Dir.pwd, '')
        cache_path = (Merb.dir_for(:config) / 'ift.cache').gsub(Dir.pwd,'')
        msg  = "Warning: Potential cache corruption. "
        msg << "File #{path} is listed in the cache "
        msg << "(#{cache_path}) but doesn't exist."
        raise msg
      else
        FileUtils.rm(file)
      end
    end
  end
end
