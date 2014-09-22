module Puppet::Parser::Functions
  newfunction :conjur_variable, :type => :rvalue do |args|
    name = args[0]

    "<%= conjurenv[#{name.inspect}] %>"
  end
end
