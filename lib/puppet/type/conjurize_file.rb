Puppet::Type.newtype(:conjurize_file) do
  newparam :path do
    isnamevar
  end

  newproperty :map do
    defaultto {}
  end
end
