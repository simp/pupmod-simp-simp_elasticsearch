# Format a passed String/Array of ip/host:port combinations into an appropriate
# ElasticSearch iptables ACCEPT rule(s).
#
# This is very much ElasticSearch specific.

Puppet::Functions.create_function(:'simp_elasticsearch::iptables_format') do
  # @param host_info
  #   A single ES host in 'ip:port' or 'host:port' format
  dispatch :iptables_format do
    required_param 'String', :host_info
  end

  # @param host_info
  #   An Array of one or more ES hosts, each in 'ip:port' or 'host:port'
  #   format
  dispatch :iptables_format do
    required_param 'Array', :host_info
  end

  def iptables_format(host_info)
    es_hosts = Array(host_info)

    iptables_rules = []

    es_hosts.each do |es_host|
      host,port = split_port(es_host)

      if not port or port !~ /^\d+$/ then
        fail("simp_elasticsearch::iptables_format: Error, '#{es_host}' missing a valid port.")
      end

      call_function('validate_net_list', Array(host))

      iptables_rules << "-s #{host} -p tcp -m state --state NEW -m tcp -m multiport --dports #{port} -j ACCEPT"
    end

    # We should never hit this but, if we do, we need to know.
    fail("simp_elasticsearch::iptables_format(): Error, iptables rules result set empty!") if
      iptables_rules.empty?

    iptables_rules.join("\n")
  end

  # Return a host/port pair
  def split_port(host_string)
    #TODO figure out why the call to Simplib.split_port doesn't work, so
    # we don't have to replicate that code
#    require 'puppetx/simp/simplib'
#    host,port = PuppetX::Simp::Simplib.split_port(host_string)
#    # remove [] for IPv6
#    host.gsub!('[', '')
#    host.gsub!(']', '')

    return [nil,nil] if host_string.nil? or host_string.empty?

    # CIDR addresses do not have ports
    return [host_string, nil] if host_string.include?('/')

    # IPv6 Easy
    if host_string.include?(']')
      host_pair = host_string.split(/\]:?/)
      host_pair[1] = nil if host_pair.size == 1

      # remove '[' and ']' from IPv6 address
       host_pair[0].gsub!('[', '')
       host_pair[0].gsub!(']', '')
    # IPv6 Fallback
    elsif host_string.count(':') > 1
      host_pair = [host_string, nil]
    # Everything Else
    elsif host_string.include?(':')
      host_pair = host_string.split(':')
    else 
      host_pair = [host_string, nil]
    end

    host_pair
  end

end
