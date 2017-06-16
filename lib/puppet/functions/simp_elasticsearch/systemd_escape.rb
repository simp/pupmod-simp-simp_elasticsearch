# Create a string suitable for use in the name of a systemd service file
# from a service name.
#
# This mimics systemd-escape.
Puppet::Functions.create_function(:'simp_elasticsearch::systemd_escape') do
  # @param service_name
  #   Service name that needs to be escaped appropriately in order to
  #   be used as a systemd service file.
  #
  # @return String
  #   Transformed version of service_name that can be used as a name of
  #   a systemd service file.
  #
  dispatch :systemd_escape do
    required_param 'String', :service_name
  end

  def systemd_escape(service_name)
    escaped_string = service_name.gsub(/([^a-zA-Z0-9_.:\/]+)/n) do
      '\x' + $1.unpack('H2' * $1.size).join('\x')
    end
    escaped_string.gsub('/', '-')
  end

end
