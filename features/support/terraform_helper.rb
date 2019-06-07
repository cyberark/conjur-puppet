require 'winrm'
require 'fileutils'
require 'ostruct'

module TerraformHelper
  def terraform_aws_environment(agents)
    return if $terraform_env_created

    $agents = agents
    generate_terraform_project($agents)
    run_terraform

    at_exit do
      destroy_terraform unless ENV['PRESERVE_PROJECT']&.downcase == 'true'
    end

    $terraform_env_created = true
  end

  def windows_agents
    $agents.select { |a| a.platform.downcase == 'windows' }
  end

  def redhat_agents
    $agents.select { |a| a.platform.downcase == 'redhat' }
  end

  private

  def generate_terraform_project(agents, destination=Pathname.new('tmp/terraform'))
    # Delete existing project directory
    FileUtils.rm_rf(destination) unless ENV['USE_EXISTING_PROJECT']&.downcase == 'true'

    # Create project directory
    FileUtils.mkdir_p(destination)

    Dir.glob(File.join('ci/template/terraform', '*')).each do |path|
      pathname = Pathname.new(path)
      if pathname.extname == '.erb'
        File.open(destination.join(pathname.basename.sub(/\.erb$/, '')), 'w') do |file|
          file.puts(ERB.new(File.read(path)).result(binding))
        end
      else
        FileUtils.cp(pathname, File.join(destination, pathname.basename))
      end
    end
  end

  def run_terraform
    Dir.chdir('tmp/terraform') do
      pid = spawn('terraform init && terraform apply --auto-approve -input=false')
      Process.wait(pid)
    end
  end

  def destroy_terraform
    Dir.chdir('tmp/terraform') do
      pid = spawn('terraform destroy --auto-approve')
      Process.wait(pid)
    end
  end
end

World(TerraformHelper)
