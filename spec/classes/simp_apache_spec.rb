require 'spec_helper'

shared_examples_for 'a simp_elasticsearch::simp_apache' do
  it { is_expected.to compile.with_all_deps }
  it { is_expected.to create_file('/etc/httpd/conf.d/elasticsearch') }
  it { is_expected.to create_file('/etc/httpd/conf.d/elasticsearch/auth') }
  it { is_expected.to create_file('/etc/httpd/conf.d/elasticsearch/limit') }
end

describe 'simp_elasticsearch::simp_apache' do
  on_supported_os.each do |os, facts|
    context "on #{os} operating system" do
      let(:facts){ facts }

      context 'with default params and manage_httpd=true' do
        let(:params) { { :manage_httpd => true } }

        it_should_behave_like 'a simp_elasticsearch::simp_apache'
        it { is_expected.to create_class('simp_apache') }
        it { is_expected.to create_class('simp_apache::ssl') }
        it { is_expected.to create_file('/etc/httpd/conf.d/elasticsearch/limit/limits.conf').with_content( <<EOM
<Limit GET>
  Order allow,deny
  Allow from 127.0.0.1
  Allow from foo.example.com
  Require all denied
  Satisfy any
</Limit>

<Limit POST>
  Order allow,deny
  Allow from 127.0.0.1
  Allow from foo.example.com
  Require all denied
  Satisfy any
</Limit>

<Limit PUT>
  Order allow,deny
  Allow from 127.0.0.1
  Allow from foo.example.com
  Require all denied
  Satisfy any
</Limit>

EOM
        ) }

        it { is_expected.to create_simp_apache__site('elasticsearch').with_content( <<EOM
# This file managed by Puppet

Listen 9200

# Doing this to keep out of the way of other Apache configurations.
<VirtualHost *:9200>

  SSLEngine on

  SSLProtocol +TLSv1 +TLSv1.1 +TLSv1.2
  SSLCipherSuite HIGH
  SSLCertificateFile /etc/pki/simp_apps/simp_apache/x509/public/foo.example.com.pub
  SSLCertificateKeyFile /etc/pki/simp_apps/simp_apache/x509/private/foo.example.com.pem
  SSLCACertificatePath /etc/pki/simp_apps/simp_apache/x509/cacerts

  SSLVerifyClient require
  SSLVerifyDepth 10

  <Proxy balancer://main>
    BalancerMember http://127.0.0.1:9199 max=1 retry=5

    <IfVersion < 2.4>
    include '/etc/httpd/conf.d/elasticsearch/auth/*.conf'
    </IfVersion>
    <IfVersion >= 2.4>
    IncludeOptional '/etc/httpd/conf.d/elasticsearch/auth/*.conf'
    </IfVersion>

    # Restrict who can write to ES.
    include '/etc/httpd/conf.d/elasticsearch/limit/*.conf'

    <LimitExcept GET POST PUT>
      Order allow,deny
    </LimitExcept>
  </Proxy>

  ProxyPass / balancer://main/
  ProxyPassReverse / balancer://main/
</VirtualHost>
EOM
        ) }
      end

      context "with manage_httpd='conf' and method_acl set" do
        let(:params) { {
          :manage_httpd => 'conf',
          :method_acl => {
            'method' => {
              'ldap'     => {
                'enable'      => true
              }
            },
            'limits' => {
              'defaults' => [ 'GET', 'POST', 'PUT' ],
              'hosts'    => {
                '1.2.3.4'     => 'defaults',
                '10.1.2.0/24' => 'defaults'
              }
            }
          }
        } }
        let(:hieradata) { 'ldap' }

        it_should_behave_like 'a simp_elasticsearch::simp_apache'
        it { is_expected.to create_class('simp_elasticsearch::pki') }
        it { is_expected.to create_file('/etc/httpd/conf.d/elasticsearch/limit/limits.conf').with_content( <<EOM
<Limit GET>
  Order allow,deny
  Allow from 1.2.3.4
  Allow from 10.1.2.0/24
  Allow from 127.0.0.1
  Allow from foo.example.com
  Require all denied
  Satisfy any
</Limit>

<Limit POST>
  Order allow,deny
  Allow from 1.2.3.4
  Allow from 10.1.2.0/24
  Allow from 127.0.0.1
  Allow from foo.example.com
  Require all denied
  Satisfy any
</Limit>

<Limit PUT>
  Order allow,deny
  Allow from 1.2.3.4
  Allow from 10.1.2.0/24
  Allow from 127.0.0.1
  Allow from foo.example.com
  Require all denied
  Satisfy any
</Limit>

EOM
        ) }

        it { is_expected.to create_simp_apache__site('elasticsearch') }
  it { is_expected.to create_file('/etc/httpd/conf.d/elasticsearch/auth/auth.conf').with_content( <<EOM
AuthName "Please Authenticate"
AuthType Basic
AuthBasicProvider ldap
AuthLDAPUrl "ldap://server1 server2/ou=People,dc=example,dc=com" STARTTLS
AuthLDAPBindDN "cn=hostAuth,ou=People,dc=example,dc=com"
AuthLDAPBindPassword 'B1nd=P@ssw0rd=F0r=T3st'
AuthLDAPGroupAttributeIsDN off
AuthLDAPGroupAttribute memberUid
EOM
  ) }
      end

    end
  end
end
