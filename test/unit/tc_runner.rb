require File.expand_path('../../../lib/runner',  __FILE__)
require 'test/unit'
require 'fileutils'

class TestSyncophantRunner < Test::Unit::TestCase
 
  def setup
    @settings = Syncophant::Runner.load_config('test/config/config.yml')
    FileUtils.rm_rf(@settings['target']) if File.exists?(@settings['target'])
    Dir.mkdir(@settings['target'])
  end
  
  def teardown
    FileUtils.rm_rf(@settings['target'])
  end
  
  def test_load_config
    assert_equal('./test/source',@settings['source'])
  end
 
  def test_initialize_directories
    assert_equal(false,File.exists?("#{@settings['target']}/hourly"))
    Syncophant::Runner.initialize_root_frequency_folders
    assert_equal(true,File.exists?("#{@settings['target']}/hourly"))
  end
  
  def test_run
    t = Time.now
    assert_equal(true,File.exists?("#{@settings['source']}/README"))
    assert_equal(false,File.exists?("#{@settings['target']}/hourly/#{sprintf("%04d-%02d-%02d.%02d", t.year, t.month, t.day, t.hour)}/source/README"))
    Syncophant::Runner.run('test/config/config.yml')
    assert_equal(true,File.exists?("#{@settings['target']}/hourly/#{sprintf("%04d-%02d-%02d.%02d", t.year, t.month, t.day, t.hour)}/source/README"))
    
  end
 end
