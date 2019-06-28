
require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'
require 'puppet_blacksmith/rake_tasks'

PuppetLint.configuration.relative = true

desc "Validate manifests, templates, and ruby files"
task :syntax_validate do
  Dir['manifests/**/*.pp'].each do |manifest|
    flags = ENV['FUTURE_PARSER'] == 'yes' ? '--parser future' : ''
    sh "puppet parser validate  --noop #{flags}  #{manifest}"
  end
  Dir['spec/**/*.rb','lib/**/*.rb'].each do |ruby_file|
    sh "ruby -c #{ruby_file}" unless ruby_file =~ /spec\/fixtures/
  end
  Dir['templates/**/*.erb'].each do |template|
    sh "erb -P -x -T '-' #{template} | ruby -c"
  end
  #Validate epp template Checks
  Dir['templates/**/*.epp'].each do |template|
    # Although you can use epp with Puppet < 4 + future parser, the epp
    # subcommand won't be available so we can't actually test these :(
    unless ENV['FUTURE_PARSER'] == "yes"
      sh "puppet epp validate  #{template}"
    end
  end
end

PuppetLint::RakeTask.new :lint  # Not sure why I have to do this, but task gives no output otherwise

task :test => [:syntax_validate, :lint, :spec]

task :package do
  Rake::Task['module:clean'].invoke
  sh 'puppet module build .'
  sh 'ls -lh pkg/*tar.gz'
  sh 'tar -tvf pkg/cyberark-conjur*.tar.gz'
end

desc 'Release the module to Puppet Forge'
task :release => [:package] do
  Rake::Task['module:push'].invoke
end
