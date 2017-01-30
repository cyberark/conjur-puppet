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

desc 'Lint module and metadata'
task :lint do
  sh 'metadata-json-lint --no-fail-on-warnings metadata.json'
  sh 'puppet-lint --relative --no-autoloader_layout-check .'
end

desc 'Run unit tests'
task :spec do
  sh "rspec --pattern --pattern spec/**/*.rb --exclude-pattern spec/fixtures/**/*_spec.rb "\
     "--format documentation --format RspecJunitFormatter --out rspec.xml"
end
