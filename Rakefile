require 'bundler/gem_tasks'
require 'rake/testtask'

def load_libs(rake_task)
  rake_task.libs << 'test'
  rake_task.libs << 'lib'
end

Rake::TestTask.new(:test) do |rake_task|
  load_libs rake_task
  rake_task.test_files = FileList['test/**/*-test.rb']
end

Rake::TestTask.new(:manual_test) do |rake_task|
  load_libs rake_task
  rake_task.test_files = FileList['manual_test.rb']
end

task default: :test
