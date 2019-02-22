require "bundler/gem_tasks"
require "rake/testtask"

def load_libs(t)
  t.libs << "test"
  t.libs << "lib"
end

Rake::TestTask.new(:test) do |t|
  load_libs t
  t.test_files = FileList['test/**/*-test.rb']
end

Rake::TestTask.new(:manual_test) do |t|
  load_libs t
  t.test_files = FileList['manual_test.rb']
end

task :default => :test
