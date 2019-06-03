require 'puppet/type'

Puppet::Type.newtype(:credential) do
  @doc = <<-EOT
    Manages Credential Manager credentials on Windows systems.
  EOT

  ensurable

  newparam(:target, :namevar =>  true) do
  end

  newproperty(:username) do
  end

  newproperty(:value) do
  end
end
