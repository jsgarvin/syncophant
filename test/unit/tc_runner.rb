require File.expand_path('../../../lib/runner',  __FILE__)
require 'test/unit'
require 'fileutils'

class TestSyncophantRunner < Test::Unit::TestCase
 
  def setup
    @settings = Syncophant::Runner.load_config('test/config/config.yml')
    FileUtils.rm_rf(@settings['target'])
    Dir.mkdir(@settings['target'])
  end
  
  def teardown
    FileUtils.rm_rf(@settings['target'])
    Dir.mkdir(@settings['target'])
  end
  
  def test_load_config
    assert_equal('./test/source',@settings['source'])
  end
 
  def test_initialize_directories
    assert_equal(false,File.exists?("#{@settings['target']}/hourly"))
    Syncophant::Runner.initialize_folders
    assert_equal(true,File.exists?("#{@settings['target']}/hourly"))
  end
 end
