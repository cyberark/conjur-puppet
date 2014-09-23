Puppet::Type.newtype(:conjurize_file) do
  newparam :path do
    isnamevar
  end

  newproperty :variable_map do
    defaultto {}
  end
end
