require 'lib/runner'
require 'test/unit'

class TestSyncophantRunner < Test::Unit::TestCase
 
  def test_load_config
     Syncophant::Runner.send('load_config','test/config/config.yml')
     assert_equal('./test/source',Syncophant::Runner.instance_variable_get('@settings')['test_one']['source'])
   end
 
 end
