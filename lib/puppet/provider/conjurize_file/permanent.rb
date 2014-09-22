Puppet::Type.type(:conjurize_file).provide(:permanent) do
  has_command :conjur, '/opt/conjur/bin/conjur' do
    environment :HOME => "/var/tmp"
  end

  def map
    nil
  end

  def map= _map
    @map = _map
    apply
  end

  private

  def apply
    # any better way to force the ordering?
    resource.catalog.resource(:class, 'conjur::host_identity').refresh
    resource.catalog.resource(:class, 'conjur::client').refresh

    # don't save the secrets to a bucket
    file[:backup] = false
    
    file[:content] = render
    file.write :content
    cleanup
  end

  def cleanup
    [:@rendered_file, :@template_file, :@map_file].each do |v|
      FileUtils.rm instance_variable_get v
      instance_variable_set v, nil
    end
  end

  def path
    path = resource[:path]
  end

  def render
    File.read rendered_file
  end

  def rendered_file
    @rendered_file ||= conjur(['env', 'template', '-c', map_file, template_file]).strip
  end

  def file
    @file ||= resource.catalog.resource :file, path
  end

  def template
    @template ||= file.property(:content).actual_content
  end

  def template_file
    @template_file ||= write_temp 'template', template
  end

  def map_file
    @map_file ||= write_temp 'map', prepare_map(@map)
  end

  def write_temp name, content
    f = Tempfile.new name
    f.write content
    f.close
    f.path
  end

  def prepare_map map
    map.map do |k, v|
      [k, v].join ': '
    end.join("\n")
  end
end
