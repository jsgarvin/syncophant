require File.expand_path('../lock_file',  __FILE__)
require 'yaml'
require 'fileutils'

module Syncophant
  class Runner
    class << self
      FREQUENCIES = [:hourly,:daily,:weekly,:monthly,:yearly]
      
      def run(path_to_config = nil, job_name = nil)
        load_config(path_to_config,job_name)
        Syncophant::LockFile.new do
          initialize
          purge_old_backups
          run_backups
        end
      end
      
      def load_config(path_to_config = nil, job_name = nil)
        @path_to_config = path_to_config || 'config/config.yml'
        @job_name = job_name  ||  'default'
        @settings = YAML.load_file(@path_to_config)[@job_name]
        if @settings['rsync_flags']
          #split rsync_flags into an array and strip leading and trailing single quotes from --exclude arguments
          @settings['rsync_flags'] = @settings['rsync_flags'].split(/ /).map {|arg| arg.gsub(/^\'/,'').gsub(/\'$/,'') } 
        end
      end
      
      def save_config
        full_settings = YAML.load_file(@path_to_config)
        full_settings[@job_name] = @settings
        full_settings[@job_name]['rsync_flags'] = full_settings[@job_name]['rsync_flags'].join(' ')
        File.open(@path_to_config, 'w') {|f| f.write(full_settings.to_yaml) }
      end
      
      #Must be done first over nfs so that ownerships are correct.  If created by rsync daemon on readynas, root will own
      #the folders and you'll never be able to delete them. 
      def initialize
        FREQUENCIES.each do |frequency|
          Dir.mkdir(root_nfs_target(frequency)) unless File.exists?(root_nfs_target(frequency)) && File.directory?(root_nfs_target(frequency))
        end
        if previous_target_name(:hourly) != last_successful_hourly_target and !last_successful_hourly_target.nil? and File.exists?(root_nfs_target(:hourly) + '/' + last_successful_hourly_target)
          File.rename(previous_nfs_target(:hourly), current_nfs_target(:hourly))
          @previous_target_name[:hourly] = last_successful_hourly_target
        end
      end
      
      def source
        @settings['source']
      end
      
      def last_successful_hourly_target
        @settings['last_successful_hourly_target']
      end
      
      def nfs_path
        @settings['nfs_path']
      end
      
      def rsync_daemon_address
        @settings['rsync_daemon_path']
      end
     
      def previous_target_name(frequency)
        @previous_target_name ||= {}
        return @previous_target_name[frequency] if @previous_target_name[frequency]
        full_path = Dir[root_nfs_target(frequency)+'/*'].sort{|a,b| File.ctime(b) <=> File.ctime(a) }.first
        @previous_target_name[frequency] = full_path ? File.basename(full_path) : ''
      end
      
      def current_target_name(frequency)
        @time ||= Time.now #lock in time so that all results stay consistent over long runs
        case frequency
          when :hourly  then @time.strftime('%Y-%m-%d.%H')
          when :daily   then @time.strftime('%Y-%m-%d')
          when :weekly  then sprintf("%04d-%02d-week-%02d", @time.year, @time.month, (@time.day/7))
          when :monthly then @time.strftime("%Y-%m")
          when :yearly  then @time.strftime("%Y")
        end
      end
      
      def root_nfs_target(frequency)
        "#{nfs_path}/#{frequency}"
      end
      
      def root_daemon_target(frequency)
        "#{rsync_daemon_address}/#{frequency}"
      end
      
      def current_nfs_target(frequency)
        root_nfs_target(frequency) + '/' + current_target_name(frequency)
      end
      
      def previous_nfs_target(frequency)
        root_nfs_target(frequency) + '/' + previous_target_name(frequency)
      end
      
      def current_daemon_target(frequency)
        root_daemon_target(frequency) + '/' + current_target_name(frequency)
      end
      
      def link_destination(frequency)
        frequency == :hourly ? "../#{previous_target_name(:hourly)}" : "../../hourly/#{current_target_name(:hourly)}"
      end
      
      def run_backups
        FREQUENCIES.each do |frequency|
          Dir.mkdir(current_nfs_target(frequency)) unless File.exists?(current_nfs_target(frequency))
          if frequency == :hourly and previous_target_name(frequency) == ''
            system 'rsync', *(['-aq', '--delete'] + @settings['rsync_flags'] + [source, current_daemon_target(frequency)])          
          elsif previous_target_name(frequency) != current_target_name(frequency)
            system 'rsync', *(['-aq', '--delete', "--link-dest=#{link_destination(frequency)}"] + @settings['rsync_flags'] + [source, current_daemon_target(frequency)])
          end
        end
        unless previous_target_name(:hourly) == current_target_name(:hourly)
          @settings['last_successfull_hourly_target'] = current_target_name(:hourly)
          save_config
        end
      end
      
      def purge_old_backups
        purge_count = {:hourly => 24, :daily => 7, :weekly => 5, :monthly => 12}
        purge_count.keys.each do |frequency|
          while Dir[root_nfs_target(frequency)+'/*'].size > purge_count[frequency]
            FileUtils.rm_rf(Dir[root_nfs_target(frequency)+'/*'].sort{|a,b| File.ctime(a) <=> File.ctime(b) }.first)
          end
        end
      end
    end
  end
end