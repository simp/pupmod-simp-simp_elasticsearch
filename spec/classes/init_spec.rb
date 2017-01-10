require 'spec_helper'

describe 'simp_elasticsearch' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:facts){ facts }
      default_params = {
        :cluster_name => 'es_cluster'
      }
      let(:conf_manifest) {
       <<-EOM
          service { 'httpd':
            ensure => running,
          }
        EOM
      }

      context "with default params" do
        let(:params) {
          default_params
        }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('simp_elasticsearch') }
        it { is_expected.to_not create_class('iptables') }
        it { is_expected.to create_class('simp_elasticsearch::simp_apache') }
        it { is_expected.to create_class('pam::limits') }
        it { is_expected.to create_class('simp_apache') }
      end

     context "with manage_httpd and firewall" do
       let(:params) do default_params.merge({
            :manage_httpd => 'conf',
            :firewall     => true,
          })
        end
        let(:pre_condition) {'include simp_apache'}

        it {is_expected.to create_class('simp_elasticsearch::pki')}
        it { is_expected.to create_class('iptables') }
        it { is_expected.to create_class('simp_elasticsearch::simp_apache') }
     end

    end
  end
end
