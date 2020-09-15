# frozen_string_literal: true

require 'puppet/type'

# Manages Credential Manager credentials on Windows systems.
Puppet::Type.newtype(:credential) do
  @doc = 'Manages Credential Manager credentials on Windows systems.'

  ensurable

  newparam(:target, namevar: true) do
    desc 'Conjur / DAP URL'
  end

  newproperty(:username) do
    desc 'The identity used to authenticate to the Conjur / DAP instance'
  end

  newproperty(:value) do
    desc 'The API key matching the Conjur / DAP identity'
  end
end
