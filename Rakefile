require 'puppetlabs_spec_helper/rake_tasks' # needed for some module packaging tasks
require 'puppet_blacksmith/rake_tasks'

if RUBY_VERSION >= '1.9'
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
end

desc 'Validate manifests, templates, and ruby files'
task :validate do
  Dir['manifests/**/*.pp'].each do |manifest|
    sh "puppet parser validate --noop #{manifest}"
  end
  Dir['spec/**/*.rb', 'lib/**/*.rb'].each do |ruby_file|
    sh "ruby -c #{ruby_file}" unless ruby_file =~ %r{spec/fixtures}
  end
  Dir['templates/**/*.erb'].each do |template|
    sh "erb -P -x -T '-' #{template} | ruby -c"
  end
end

PuppetLint::RakeTask.new :lint do |config|
  config.disable_checks = ['documentation', 'arrow_alignment']
end

desc 'Run unit tests'
task :spec do
  sh "rspec --pattern --pattern spec/**/*.rb --exclude-pattern spec/fixtures/**/*_spec.rb "\
     "--format documentation --format RspecJunitFormatter --out rspec.xml"
end

desc 'Release the module to Puppet Forge'
task :release do
  Rake::Task['module:clean'].invoke
  sh 'puppet module build .'
  sh 'ls -lh pkg/*tar.gz'
  sh 'tar -tvf pkg/conjur-conjur*.tar.gz'
  Rake::Task['module:push'].invoke
end

desc 'Build a nightly package'
task :nightly do
  require 'json'
  metadata = JSON.load File.read 'metadata.json'
  nightstamp = Time.now.utc.strftime('%m%d')

  # I really wanted to do 1.0.0.alpha.201, but puppet doesn't
  # like that: https://tickets.puppetlabs.com/browse/PUP-4951
  version = metadata['version'] += nightstamp
  sh "git tag v#{version}"
  begin
    FileUtils.mv 'metadata.json', 'metadata.json.orig'
    File.write 'metadata.json', metadata.to_json
    sh "puppet module build ."
    unless ENV['DONT_PUSH']
      sh "git push origin tag v#{version}"
      puts "README is public at https://github.com/conjur/puppet/blob/v#{version}/README.md"
    end
  rescue
    sh "git tag -d v#{version}"
  ensure
    FileUtils.mv 'metadata.json.orig', 'metadata.json'
  end
end
