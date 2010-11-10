module Syncophant
  class Runner
    class << self
      FREQUENCIES = [:hourly,:daily,:weekly,:monthly,:annually]
      
      def run
        load_config
        initialize_folders
      end
      
      #######
      private
      #######
      
      def load_config
        @settings = YAML.load_file('config/config.yml')
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