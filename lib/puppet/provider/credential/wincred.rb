require 'puppet/type'
require 'wincred/wincred' if Puppet.features.microsoft_windows?

Puppet::Type.type(:credential).provide(:wincred) do
  defaultfor :operatingsystem => :windows
  confine    :operatingsystem => :windows

  def exists?
    Puppet.debug("Checking the existence of WinCred credential: #{self}")
    WinCred.exist?(resource.parameter(:target).value)
  end

  def create
    Puppet.debug("Creating WinCred credential: #{self}")
    write_value
  end

  def flush
    Puppet.debug("Flushing WinCred credential: #{self}")

    if resource[:ensure] == :absent
      destroy
    else
      write_value
    end
  end

  def destroy
    Puppet.debug("Destroying WinCred credential: #{self}")
    WinCred.delete_credential(resource.parameter(:target).value)
  end

  def username
    current_value[:username] || :absent
  end

  def username=(value)
    current_value[:username] = value
  end

  def value
    current_value[:value].force_encoding('utf-8') || :absent
  end

  def value=(value)
    current_value[:value] = value.force_encoding('ascii-8bit')
  end

  private

  def write_value
    WinCred.write_credential(
      target: resource.parameter(:target).value,
      username: resource[:username],
      value: resource[:value].force_encoding('ascii-8bit')
    )
  end

  def current_value
    @current_value ||= WinCred.read_credential(resource.parameter(:target).value)
  end
end
