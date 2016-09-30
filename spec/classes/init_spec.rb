require 'spec_helper'

describe 'simp_elasticsearch' do
  context 'supported operating systems' do
    on_supported_os.each do |os, facts|
      let(:facts){facts }
      default_params = {
        :cluster_name => 'es_cluster'
      }

      context "on #{os}" do
        let(:params) {
          default_params
        }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to create_class('simp_elasticsearch') }
        it { is_expected.to create_class('iptables') }
        it { is_expected.to create_class('simp_elasticsearch::simp_apache') }
        it { is_expected.to create_class('pam::limits') }
      end
    end
  end
end
