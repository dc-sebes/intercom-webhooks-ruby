require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << '.'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

task :default => :test

desc "Run all tests"
task :test_all => :test

desc "Run unit tests only"
Rake::TestTask.new(:test_unit) do |t|
  t.libs << 'test'
  t.libs << '.'
  t.test_files = FileList['test/asana_client_test.rb']
  t.verbose = true
end

desc "Run integration tests only"
Rake::TestTask.new(:test_integration) do |t|
  t.libs << 'test'
  t.libs << '.'
  t.test_files = FileList['test/integration_test.rb', 'test/endpoints_test.rb']
  t.verbose = true
end

desc "Run tests with coverage (if simplecov is available)"
task :test_coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task[:test].invoke
end