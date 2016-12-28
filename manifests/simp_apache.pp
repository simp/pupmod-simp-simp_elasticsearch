# This class provides the configuration of Apache for use as a front-end to
# ElasticSearch. The defaults are targeted toward making the interface as
# highly available as possible without regard to system load.
#
# @param manage_http Whether or not to manage the httpd daemon/apache
#   itself.
#
#   @note This class assumes that you're using the simp-supplied apache module
#     and calls apache::add_site accordingly. If you're not comfortable doing
#     this, you don't want to use this module.
#
# @param listen The port upon which to listen for HTTP connections.
#
# @param proxy_port The port to proxy HTTP connections to on the local
#   system.
#
# @param method_acl Users, Groups, and Hosts HTTP operation ACL
#   management. Keys are the relevant entry to allow and values are an Array of
#   operations to allow the key to use.
#
#   @note These are OR'd together (Satisfy any).
#
#   @example ACL Structure
#
#     # If no value is assigned to the associated key then ['GET','POST','PUT']
#     # is assumed.
#
#     # Values will be merged with those in simp_elasticsearch::simp_apache::defaults
#     # if defined.
#
#     {
#       'limits'  => {
#         'hosts'   => {
#           '127.0.0.1' => ['GET','POST','PUT']
#         }
#       }
#     }
#
#   @example Use LDAP with the defaults and only allow localhost
#
#     {
#       'method' => {
#         'ldap' => {
#           'enable' => true
#         }
#       }
#     }
#
#   @example Full example with all options
#
#     {
#       # 'file' (htpasswd), and 'ldap' support are provided. You will need to
#       # set up target files if using 'file'. The SIMP apache module provides
#       # automated support for this if required.
#       'method' => {
#         # Htpasswd only supports 'file' at this time. If you need more, please
#         # use 'ldap'
#         'file' => {
#           # Don't turn this on.
#           'enable'    => false,
#           'user_file' => '/etc/httpd/conf.d/elasticsearch/.htdigest'
#         }
#         'ldap'    => {
#           'enable'      => true,
#           'url'         => hiera('ldap::uri'),
#           'security'    => 'STARTTLS',
#           'binddn'      => hiera('ldap::bind_dn'),
#           'bindpw'      => hiera('ldap::bind_pw'),
#           'search'      => inline_template('ou=People,<%= scope.function_hiera(["ldap::base_dn"]) %>'),
#           # Whether or not your LDAP groups are POSIX groups.
#           'posix_group' => true
#         }
#       },
#       'limits' => {
#         # Set the defaults
#         'defaults' => [ 'GET', 'POST', 'PUT' ],
#         # Allow the hosts/subnets below to GET, POST, and PUT to ES.
#         'hosts'  => {
#           '1.2.3.4'     => 'defaults',
#           '3.4.5.6'     => 'defaults',
#           '10.1.2.0/24' => 'defaults'
#         },
#         # You can make a special user 'valid-user' that will translate to
#         # allowing all valid users.
#         'users'  => {
#           # Allow user bob GET, POST, and PUT to ES.
#           'bob'     => 'defaults',
#           # Allow user alice GET, POST, PUT, and DELETE to ES.
#           'alice'   => ['GET','POST','PUT','DELETE']
#         },
#         'ldap_groups' => {
#           # Let the nice users read from ES.
#           "cn=nice_users,ou=Group,${::basedn}" => 'defaults'
#         }
#       }
#     }
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
# @copyright 2016 Onyx Point, Inc.
#
class simp_elasticsearch::simp_apache (
  Boolean              $manage_httpd      = true,
  Simplib::Port        $listen            = 9200,
  Simplib::Port        $proxyport         = 9199,
  Array[String]        $cipher_suite      = simplib::lookup('simp_options::openssl::cipher_suite', { 'default_value' => ['HIGH'] } ),
  Stdlib::AbsolutePath $app_pki_cert      = "/etc/pki/public/${facts['fqdn']}.pub",
  Stdlib::AbsolutePath $app_pki_key       = "/etc/pki/private/${facts['fqdn']}.pem",
  Stdlib::AbsolutePath $app_pki_ca_dir    = '/etc/pki/cacerts',
  Array[String]        $ssl_protocols     = ['+TLSv1','+TLSv1.1','+TLSv1.2'],
  String               $ssl_verify_client = 'require',
  Integer              $ssl_verify_depth  = 10,
  Hash                 $method_acl        = {}
) {

  include '::simp_elasticsearch::simp_apache::defaults'
  include '::simp_apache::validate'

  $_method_acl = deep_merge(
    $::simp_elasticsearch::simp_apache::defaults::method_acl,
    $method_acl
  )

  validate_deep_hash( $::simp_apache::validate::method_acl, $_method_acl)

  # These only work because we guarantee that we have content here.
  validate_absolute_path($_method_acl['method']['file']['user_file'])
  validate_bool_simp($_method_acl['method']['ldap']['posix_group'])
  validate_net_list(keys($_method_acl['limits']['hosts']))

  $es_httpd_includes = '/etc/httpd/conf.d/elasticsearch'

  if $manage_httpd or $manage_httpd == 'conf' {
    include 'simp_apache::ssl'
    include 'simp_apache::conf'

    $_app_pki_cert   = $::simp_apache::ssl::app_pki_cert
    $_app_pki_key    = $::simp_apache::ssl::app_pki_key
    $_app_pki_ca_dir = $::simp_apache::ssl::app_pki_ca_dir

    simp_apache::add_site { 'elasticsearch':
      content => template("${module_name}/simp/etc/httpd/conf.d/elasticsearch.conf.erb")
    }

    file { $es_httpd_includes:
      ensure  => 'directory',
      owner   => 'root',
      group   => 'apache',
      mode    => '0640',
      require => Package['httpd']
    }

    file { [
      "${es_httpd_includes}/auth",
      "${es_httpd_includes}/limit",
    ]:
      ensure => 'directory',
      owner  => 'root',
      group  => 'apache',
      mode   => '0640'
    }

    $_apache_auth = apache_auth($_method_acl['method'])

    if !empty($_apache_auth) {
      file { "${es_httpd_includes}/auth/auth.conf":
        ensure  => 'file',
        owner   => 'root',
        group   => 'apache',
        mode    => '0640',
        content => "${_apache_auth}\n",
        notify  => Service['httpd']
      }
    }

    $_apache_limits = apache_limits($_method_acl['limits'])
    $_apache_limits_content = $_apache_limits ? {
        # Set some sane defaults.
        ''      => "<Limit GET POST PUT DELETE>
            Order deny,allow
            Deny from all
            Allow from 127.0.0.1
            Allow from ${facts['fqdn']}
          </Limit>",
        default => "${_apache_limits}\n"
    }

    file { "${es_httpd_includes}/limit/limits.conf":
      ensure  => 'file',
      owner   => 'root',
      group   => 'apache',
      mode    => '0640',
      content => $_apache_limits_content,
      notify  => Service['httpd']
    }
  }
  else {
    $_app_pki_cert   = $app_pki_cert
    $_app_pki_key    = $app_pki_key
    $_app_pki_ca_dir = $app_pki_ca_dir
  }
}
