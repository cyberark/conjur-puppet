module Util
  module Terraform
    class << self
      def output(name)
        Dir.chdir("tmp/terraform") do
          json = `terraform output -json #{name}`
          JSON.parse(json)['value'] if json && json != ''
        end
      end
    end
  end
end
