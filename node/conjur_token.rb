Facter.add('conjur_token') do
  setcode do
    Facter::Util::Resolution.exec("conjur authn authenticate")
  end
end
