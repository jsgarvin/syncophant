module Syncophant
  class LockFile
    
    def initialize
      @path = '/tmp'
      @filename = 'syncophant.lock'
      begin
        lock!
        yield
      ensure
        unlock!
      end
    end
    
    def lock_file
      "#{@path}/#{@filename}"
    end
    
    def lock!
      File.open(lock_file, "a") { |file| file.write("#{Process.pid}\n") }
      raise LockFileExists unless lock_file_acquired?
    end
    
    def unlock!
      begin
        File.delete(lock_file) if lock_file_acquired? 
      rescue
        raise LockFileMissing
      end
    end

    def lock_file_acquired?
      File.open(lock_file, "r") { |file| file.gets.to_i == Process.pid }
    end
  end
  
  class LockFileExists < StandardError; end
  class LockFileMissing < StandardError; end

end