require 'yaml'

module Syncophant
  class Runner
    class << self
      FREQUENCIES = [:hourly,:daily,:weekly,:monthly,:annually]
      
      def run(path_to_config = nil, job_name = nil)
        load_config(path_to_config,job_name)
        initialize_root_frequency_folders
        return if previous_hourly_target == current_hourly_target  #already ran within the last hour
        purge_old_backups
        run_backups
      end
      
      def load_config(path_to_config = nil, job_name = nil)
        @settings = YAML.load_file(path_to_config || 'config/config.yml')[job_name ||  'default']
        if @settings['rsync_flags']
          #split rsync_flags into an array and strip leading and trailing single quotes from --exclude arguments
          @settings['rsync_flags'] = @settings['rsync_flags'].split(/ /).map {|arg| arg.gsub(/^\'/,'').gsub(/\'$/,'') } 
        end
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
        if previous_hourly_target.nil? or File.exists?(current_hourly_target)
          system 'rsync', *(['-aq', '--delete'] + @settings['rsync_flags'] + [source, current_hourly_target])          
        else
          system 'rsync', *(['-aq', '--delete', "--link-dest=#{previous_hourly_target}"] + @settings['rsync_flags'] + [source, current_hourly_target])
        end
        system 'cp', '-rl', current_hourly_target, current_daily_target unless previous_daily_target == current_daily_target
        system 'cp', '-rl', current_hourly_target, current_weekly_target unless previous_weekly_target == current_weekly_target
        system 'cp', '-rl', current_hourly_target, current_monthly_target unless previous_monthly_target == current_monthly_target
        system 'cp', '-rl', current_hourly_target, current_annually_target unless previous_annually_target == current_annually_target
      end
      
      def purge_old_backups
        while Dir[send("root_hourly_target")+'/*'].size > 24
          File.delete(Dir[send("root_hourly_target")+'/*'].sort{|a,b| File.ctime(a) <=> File.ctime(b) }.first)
        end
        while Dir[send("root_daily_target")+'/*'].size > 7
          File.delete(Dir[send("root_daily_target")+'/*'].sort{|a,b| File.ctime(a) <=> File.ctime(b) }.first)
        end
        while Dir[send("root_weekly_target")+'/*'].size > 5
          File.delete(Dir[send("root_weekly_target")+'/*'].sort{|a,b| File.ctime(a) <=> File.ctime(b) }.first)
        end
        while Dir[send("root_monthly_target")+'/*'].size > 12
          File.delete(Dir[send("root_monthly_target")+'/*'].sort{|a,b| File.ctime(a) <=> File.ctime(b) }.first)
        end
      end
    end
  end
end