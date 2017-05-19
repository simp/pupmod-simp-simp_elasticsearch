module Puppet::Parser::Functions

  newfunction(:es_systemd_escape, :type => :rvalue, :arity =>1, :doc => <<-'ENDHEREDOC') do |args|
    Create a string suitable for use in the name of a systemd service file.

    This mimics systemd-escape.

    ENDHEREDOC

    raise Puppet::ParseError, "es_systemd_escape(): Expects a string argument, got " +
      "#{args[0].inspect} which is of type #{args[0].class}" unless args[0].is_a?(String)

    escaped_string = args[0].gsub(/([^a-zA-Z0-9_.:\/]+)/n) do
      '\x' + $1.unpack('H2' * $1.size).join('\x')
    end
    escaped_string.gsub('/', '-')
  end

end
