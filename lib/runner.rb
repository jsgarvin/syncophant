require 'yaml'
require 'fileutils'

class Syncophant
  class << self
    FREQUENCIES = [:hourly,:daily,:weekly,:monthly,:yearly]
    
    def run(path_to_config = nil, job_name = nil)
      load_config(path_to_config,job_name)
      initialize
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
    
    #Must be done first over nfs so that ownerships are correct.  If created by rsync daemon on readynas, root will own
    #the folders and you'll never be able to delete them. 
    def initialize
      FREQUENCIES.each do |frequency|
        Dir.mkdir(root_nfs_target(frequency)) unless File.exists?(root_nfs_target(frequency)) && File.directory?(root_nfs_target(frequency))
        previous_target_name(frequency)
      end
    end
    
    def source
      @settings['source']
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
      time = Time.now
      case frequency
        when :hourly  then sprintf("%04d-%02d-%02d.%02d", time.year, time.month, time.day, time.hour)
        when :daily   then sprintf("%04d-%02d-%02d", time.year, time.month, time.day)
        when :weekly  then time.strftime("%Y-%W")
        when :monthly then time.strftime("%Y-%B")
        when :yearly  then time.strftime("%Y")
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
    end
    
    def purge_old_backups
      while Dir[root_nfs_target(:hourly)+'/*'].size > 24
        FileUtils.rm_rf(Dir[root_nfs_target(:hourly)+'/*'].sort{|a,b| File.ctime(a) <=> File.ctime(b) }.first)
      end
      while Dir[root_nfs_target(:daily)+'/*'].size > 7
        FileUtils.rm_rf(Dir[root_nfs_target(:daily)+'/*'].sort{|a,b| File.ctime(a) <=> File.ctime(b) }.first)
      end
      while Dir[root_nfs_target(:weekly)+'/*'].size > 5
        FileUtils.rm_rf(Dir[root_nfs_target(:weekly)+'/*'].sort{|a,b| File.ctime(a) <=> File.ctime(b) }.first)
      end
      while Dir[root_nfs_target(:monthly)+'/*'].size > 12
        FileUtils.rm_rf(Dir[root_nfs_target(:monthly)+'/*'].sort{|a,b| File.ctime(a) <=> File.ctime(b) }.first)
      end
    end
  end
end