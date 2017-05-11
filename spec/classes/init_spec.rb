require 'spec_helper'

shared_examples_for 'a simp_elasticsearch profile' do |os_release_major, service_name|
  it { is_expected.to compile.with_all_deps }
  it { is_expected.to create_class('simp_elasticsearch') }
  it { is_expected.to create_class('simp_elasticsearch::config') }
  it { is_expected.to create_class('pam::limits') }
  it { is_expected.to create_class('java') }
  it { is_expected.to create_class('elasticsearch') }
  it { is_expected.to create_file('/etc/elasticsearch/templates_import') }
  it { is_expected.to create_file('/var/elasticsearch/data') }
  it { is_expected.to create_file('/usr/share/elasticsearch/config') }
  it { is_expected.to create_pam__limits__rule('es_heap_sizelock') }
  it { is_expected.to create_user('elasticsearch').with_home('/var/local/elasticsearch') }
  it { is_expected.to create_file('/var/local/elasticsearch') }
  it { is_expected.to create_file('/var/lib/elasticsearch/tmp') }
  if os_release_major == '6'
    it { is_expected.to contain_pam__limits__rule('es_nproc') }
  else
    it { is_expected.to create_file("/etc/systemd/system/#{service_name}.service.d") }
    it { is_expected.to create_file("/etc/systemd/system/#{service_name}.service.d/opts.conf") }
  end
end

describe 'simp_elasticsearch' do
  on_supported_os.each do |os, facts|
    context "on #{os} operating system" do
      let(:facts){ facts }
      let(:default_params) { { :cluster_name => 'es_cluster' } }
      let(:default_es_config) { {
        'cluster'   => { 'name' => 'es_cluster' },
        'node.name' => facts[:fqdn],
        'network'   => {
          'bind_host'    => facts[:ipaddress],
          'publish_host' => facts[:ipaddress]
        },
        'http'       => {
         'bind_host' => '127.0.0.1',
         'port'      => 9199
        },
        'path.logs'   => '/var/log/elasticsearch',
        'path.data'   => '/var/elasticsearch',
        'discovery'   => {
          'zen'       => {
            'minimum_master_nodes' => 1,
            'ping'                 => {
              'unicast' => {
                'hosts' => [ "#{facts[:fqdn]}:9300" ]
              }
            }
          }
        }
      } }

      context 'with default params' do
        let(:params) { default_params }

        it_should_behave_like 'a simp_elasticsearch profile', facts[:os][:release][:major], 'elasticsearch-es_cluster'
        it { 
          expected_config = default_es_config
          if facts[:os][:release][:major] < '7'
            expected_config['bootstrap.system_call_filter'] = false
          end
          is_expected.to create_class('elasticsearch').with( {
            :config      => expected_config
          } )
        }
        it { is_expected.to create_elasticsearch__instance('es_cluster') }
        it { is_expected.to create_class('simp_elasticsearch::simp_apache') }
        it { is_expected.to create_class('simp_apache') }
        it { is_expected.to create_class('simp_apache::ssl') }
        it { is_expected.to_not create_class('iptables') }
        it { is_expected.to_not create_class('pki') }
      end

      context "with manage_httpd='conf', http_method_acl={}, and firewall=true" do
        let(:params) do default_params.merge({
            :manage_httpd => 'conf',
            :firewall     => true
          })
        end
        let(:hieradata) { 'pki' }

        it_should_behave_like 'a simp_elasticsearch profile', facts[:os][:release][:major], 'elasticsearch-es_cluster'
        it { is_expected.to create_class('simp_elasticsearch::pki')}
        it { is_expected.to create_pki__copy('simp_elasticsearch')}
        it { is_expected.to create_file('/etc/pki/simp_apps/simp_elasticsearch/x509')}
        it { is_expected.to contain_class('pki')}
        it { is_expected.to create_class('iptables') }
        it { 
          is_expected.to create_iptables_rule('elasticsearch_allow_cluster').with({
            :content => "-s #{facts[:fqdn]} -p tcp -m state --state NEW -m tcp -m multiport --dports 9300 -j ACCEPT"
          })
        }
        it { is_expected.to create_class('simp_elasticsearch::simp_apache') }
        it { is_expected.to_not create_iptables__listen__tcp_stateful('elasticsearch_allow_remote')}
      end

      context "with manage_httpd=true, http_method_acl with 'limits', and firewall=true"  do
        let(:params) do default_params.merge({
            :manage_httpd => true,
            :http_method_acl => {
              'limits' => {
                'defaults' => [ 'GET', 'POST', 'PUT' ],
                'hosts'  => {
                  '1.2.3.4'     => 'defaults',
                  '10.1.2.0/24' => 'defaults'
                }
              }
            },
            :firewall     => true
          })
        end
        let(:hieradata) { 'pki' }

        it_should_behave_like 'a simp_elasticsearch profile', facts[:os][:release][:major], 'elasticsearch-es_cluster'
        it { 
          is_expected.to create_iptables__listen__tcp_stateful('elasticsearch_allow_remote').with({
            :trusted_nets => ['1.2.3.4', '10.1.2.0/24'],
            :dports       => [ 9200 ]
          })
        }
      end

      context 'with manage_httpd=false and spawn_default_instance=false' do
        let(:params) { default_params.merge({ 
          :manage_httpd => false,
          :spawn_default_instance => false
        }) }

        it_should_behave_like 'a simp_elasticsearch profile', facts[:os][:release][:major], 'elasticsearch'
        it { is_expected.to_not create_elasticsearch__instance('es_cluster') }
        it { is_expected.to_not create_class('simp_apache') }
        it { is_expected.to_not create_class('simp_elasticsearch::simp_apache') }
      end

      context 'with custom ES config settings' do
        let(:params) do default_params.merge({
            :es_config => {
              'http'       => {
                'port'            => 4199,
                'max_header_size' => 1000
              },
            }
          })
        end

        it_should_behave_like 'a simp_elasticsearch profile', facts[:os][:release][:major], 'elasticsearch-es_cluster'
        it 'should merge with default settings, replacing defaults and adding new settings' do
          expected_config = default_es_config
          expected_config['http']['port'] = 4199
          expected_config['http']['max_header_size'] = 1000
          if facts[:os][:release][:major] < '7'
            expected_config['bootstrap.system_call_filter'] = false
          end
          is_expected.to create_class('elasticsearch').with( {
            :config      => expected_config
          } )
        end

        it 'should use replaced ES port setting in elasticsearch httpd config' do
          is_expected.to create_simp_apache__site('elasticsearch').with_content(
            %r{   BalancerMember http://127.0.0.1:4199 max=1 retry=5})
        end
      end

    end
  end
end
