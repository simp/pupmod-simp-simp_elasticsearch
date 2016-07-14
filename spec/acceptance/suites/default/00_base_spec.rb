require 'spec_helper_acceptance'

test_name 'simp_elasticsearch class'

describe 'simp_elasticsearch class' do

  elasticsearch_servers = hosts_with_role(hosts, 'elasticsearch_server')

  ssh_allow = <<-EOM
    include '::tcpwrappers'
    include '::iptables'

    tcpwrappers::allow { 'sshd':
      pattern => 'ALL'
    }

    iptables::add_tcp_stateful_listen { 'i_love_testing':
      order => '8',
      client_nets => 'ALL',
      dports => '22'
    }
  EOM

  let(:manifest) {
    <<-EOS
      pki::copy { '/etc/httpd/conf':
        source => '/etc/pki/simp-testing/pki',
        before => Class['simp_elasticsearch']
      }

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

use_simp_pki : false

apache::rsync_web_root : false
rsync::server : "%{::fqdn}"

client_nets:
  - 'ALL'

pki_dir : '/etc/pki/simp-testing/pki'

use_simp_pki : false
use_iptables : true
    EOS
  }

  elasticsearch_servers.each do |host|
    context 'on the servers' do
      it 'should work with no errors' do
        # Need to get the secondary interface
        interfaces = fact_on(host, 'interfaces').split(',')
        interfaces.delete('lo')
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
