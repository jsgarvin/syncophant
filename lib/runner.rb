require 'yaml'

module Syncophant
  class Runner
    class << self
      FREQUENCIES = [:hourly,:daily,:weekly,:monthly,:annually]
      
      def run(path_to_config = nil)
        load_config(path_to_config)
        initialize_folders
      end
      
      #######
      private
      #######
      
      def load_config(path_to_config = 'config/config.yml')
        @settings = YAML.load_file(path_to_config)
      end
      
      def initialize_folders
        FREQUENCIES.each do |frequency|
          Dir.mkdir(send("#{frequency}_path")) unless File.exists?(send("#{frequency}_path")) && File.directory?(send("#{frequency}_path"))
        end
      end
      
      def target
        @settings['job_one']['target']
      end
      
      FREQUENCIES.each do |frequency|
        define_method("#{frequency}_path") do
          "#{target}/#{frequency}"
        end
      end
    end
  end
end