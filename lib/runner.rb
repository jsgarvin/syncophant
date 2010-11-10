require 'yaml'

module Syncophant
  class Runner
    class << self
      FREQUENCIES = [:hourly,:daily,:weekly,:monthly,:annually]
      
      def run(path_to_config = nil, job_name = nil)
        load_config(path_to_config,job_name)
        initialize_folders
      end
      
      def load_config(path_to_config = nil, job_name = nil)
        @settings = YAML.load_file(path_to_config || 'config/config.yml')[job_name ||  'default']
      end
      
      def initialize_folders
        FREQUENCIES.each do |frequency|
          Dir.mkdir(send("root_#{frequency}_path")) unless File.exists?(send("root_#{frequency}_path")) && File.directory?(send("root_#{frequency}_path"))
        end
      end
      
      def target
        @settings['target']
      end
      
      FREQUENCIES.each do |frequency|
        define_method("root_#{frequency}_path") do
          "#{target}/#{frequency}"
        end
      end
      
      
    end
  end
end