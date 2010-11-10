require 'yaml'

module Syncophant
  class Runner
    class << self
      FREQUENCIES = [:hourly,:daily,:weekly,:monthly,:annually]
      
      def run(path_to_config = nil, job_name = nil)
        load_config(path_to_config,job_name)
        initialize_root_frequency_folders
        return if previous_hourly_target == current_hourly_target  #already ran within the last hour
        run_backups
      end
      
      def load_config(path_to_config = nil, job_name = nil)
        @settings = YAML.load_file(path_to_config || 'config/config.yml')[job_name ||  'default']
      end
      
      def initialize_root_frequency_folders
        FREQUENCIES.each do |frequency|
          Dir.mkdir(send("root_#{frequency}_target")) unless File.exists?(send("root_#{frequency}_target")) && File.directory?(send("root_#{frequency}_target"))
        end
      end
      
      def source
        @settings['source']
      end
      
      def target
        @settings['target']
      end
      
      FREQUENCIES.each do |frequency|
        define_method("root_#{frequency}_target") do
          "#{target}/#{frequency}"
        end
      end
      
      def current_hourly_target
        t = Time.now
        "#{root_hourly_target}/#{sprintf("%04d-%02d-%02d.%02d", t.year, t.month, t.day, t.hour)}"
      end
      
      def previous_hourly_target
         @previous_hourly_target = Dir["#{root_hourly_target}/*"].sort{|a,b| File.ctime(b) <=> File.ctime(a) }.first
      end
     
      def run_backups
        if previous_hourly_target.nil?
          system 'rsync', '-a', source, current_hourly_target          
        end
      end
    end
  end
end