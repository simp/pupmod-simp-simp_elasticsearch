require 'spec_helper_acceptance'
require 'json'

test_name 'simp_elasticsearch class'

describe 'simp_elasticsearch class' do

  elasticsearch_servers = hosts_with_role(hosts, 'elasticsearch_server')

  ssh_allow = <<-EOM
    include '::tcpwrappers'
    include '::iptables'

    tcpwrappers::allow { 'sshd':
      pattern => 'ALL'
    }

    iptables::listen::tcp_stateful { 'i_love_testing':
      order        => 8,
      trusted_nets => ['10.0.0.0/16','127.0.0.0/2'],
      dports       => 22
    }
  EOM

  let(:manifest) {
    <<-EOS

      include '::simp_elasticsearch'

      #{ssh_allow}
    EOS
  }

  let(:hieradata) {
    <<-EOS
---
simp_elasticsearch::cluster_name : 'test_cluster'
simp_elasticsearch::bind_host : '#IPADDRESS#'
simp_elasticsearch::unicast_hosts :
  - #{hosts.map{|x| x.to_s + ':9300'}.join("\n  - ")}

simp_apache::rsync_web_root : false
simplib::options::rsync::server : "%{::fqdn}"

simp_elasticsearch::pki::app_pki_dir : '/etc/pki/es'

simplib::options::app_pki_external_source : '/etc/pki/simp-testing/pki'
simplib::options::pki : false
simplib::options::iptables : true
    EOS
  }

  elasticsearch_servers.each do |host|
    context 'on the servers' do
      it 'should work with no errors' do
        # Need to get the secondary interface
        interfaces = fact_on(host, 'interfaces').split(',')
        interfaces.delete('lo')
        # net_hash = JSON.load(fact_on(host, %(networking)))
        # ipaddr = net_hash['interfaces'][interfaces.sort.last]['ip']
        ipaddr = fact_on(host, %(ipaddress_#{interfaces.sort.last}))

        hdata = hieradata.dup
        hdata.gsub!(/#IPADDRESS#/m, ipaddr)

        set_hieradata_on(host, hdata)
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, :catch_changes => true)
      end

      it 'should be running elasticsearch' do
        on(host, %(ps -ef | grep "[e]lasticsearch"))
      end
    end
  end

  context 'cluster validation' do
    let(:host) { elasticsearch_servers.first }

    it 'should be running a healthy cluster' do
      # Give it a few seconds for the cluster to come to terms with itself
      sleep(30)

      result = on(host, %(curl -XGET 'http://localhost:9199/_cat/nodes')).stdout
      result.lines.count.should eql(elasticsearch_servers.count)
    end
  end
end
