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
        
        define_method("previous_#{frequency}_target") do
          @previous_target ||= {}
          @previous_target[frequency] = Dir[send("root_#{frequency}_target")+'/*'].sort{|a,b| File.ctime(b) <=> File.ctime(a) }.first
        end
      end
     
      def current_hourly_target
        t = Time.now
        root_hourly_target + '/' + sprintf("%04d-%02d-%02d.%02d", t.year, t.month, t.day, t.hour)
      end
     
      def current_daily_target
        t = Time.now
        root_daily_target + '/' + sprintf("%04d-%02d-%02d", t.year, t.month, t.day)
      end
      
      def current_weekly_target
        t = Time.now
        root_weekly_target + '/' + t.strftime("%Y-%W")
      end
      
      def current_monthly_target
        t = Time.now
        root_monthly_target + '/' + t.strftime("%Y-%B")
      end
      
      def current_annually_target
        t = Time.now
        root_annually_target + '/' + t.strftime("%Y")
      end
      
      def run_backups
        system 'cp', '-rl', previous_hourly_target, current_hourly_target unless previous_hourly_target.nil? or File.exists?(current_hourly_target)
        system 'rsync', '-a', source, current_hourly_target          
        system 'cp', '-rl', current_hourly_target, current_daily_target unless previous_daily_target == current_daily_target
        system 'cp', '-rl', current_hourly_target, current_weekly_target unless previous_weekly_target == current_weekly_target
        system 'cp', '-rl', current_hourly_target, current_monthly_target unless previous_monthly_target == current_monthly_target
        system 'cp', '-rl', current_hourly_target, current_annually_target unless previous_annually_target == current_annually_target
      end
    end
  end
end