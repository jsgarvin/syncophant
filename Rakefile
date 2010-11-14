require File.expand_path('../lib/syncophant',  __FILE__)


task :test do
   Dir["test/unit/tc_*"].each { |test_case| ruby test_case }
end

task :sync do
  Syncophant.run
end 