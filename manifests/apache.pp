# This class provides the configuration of Apache for use as a front-end to
# ElasticSearch. The defaults are targeted toward making the interface as
# highly available as possible without regard to system load.
#
# @param manage_http [Boolean] Whether or not to manage the httpd daemon/apache
#   itself.
#
#   @note This class assumes that you're using the simp-supplied apache module
#     and calls apache::add_site accordingly. If you're not comfortable doing
#     this, you don't want to use this module.
#
# @param listen [Port] The port upon which to listen for HTTP connections.
#
# @param proxy_port [Port] The port to proxy HTTP connections to on the local
#   system.
#
# @param method_acl [Hash] Users, Groups, and Hosts HTTP operation ACL
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
class simp_elasticsearch::apache (
  $manage_httpd                 = true,
  $listen                       = '9200',
  $proxyport                    = '9199',
  $ssl_protocols                = ['+TLSv1','+TLSv1.1','+TLSv1.2'],
  $ssl_cipher_suite             = hiera('openssl::cipher_suite',['HIGH']),
  $ssl_certificate_file         = "/etc/pki/public/${::fqdn}.pub",
  $ssl_certificate_key_file     = "/etc/pki/private/${::fqdn}.pem",
  $ssl_ca_certificate_path      = '/etc/pki/cacerts',
  $ssl_verify_client            = 'require',
  $ssl_verify_depth             = '10',
  $method_acl                   = {}
) {

  validate_array($ssl_protocols)
  validate_array($ssl_cipher_suite)

  # Option Validation (unless handled elsewhere)
  validate_port($listen)
  validate_port($proxyport)

  include '::simp_elasticsearch::apache::defaults'
  include '::simp_apache::validate'

  # Make sure we were actually given a hash.
  validate_hash($method_acl)

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
    include 'apache::ssl'
    include 'apache::conf'

    $_ssl_certificate_file = $::simp_apache::ssl::sslcertificatefile
    $_ssl_certificate_key_file = $::simp_apache::ssl::sslcertificatekeyfile
    $_ssl_ca_certificate_path = $::simp_apache::ssl::sslcacertificatepath

    apache::add_site { 'elasticsearch':
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

    file { "${es_httpd_includes}/limit/limits.conf":
      ensure  => 'file',
      owner   => 'root',
      group   => 'apache',
      mode    => '0640',
      content => $_apache_limits ? {
        # Set some sane defaults.
        ''      => "<Limit GET POST PUT DELETE>
            Order deny,allow
            Deny from all
            Allow from 127.0.0.1
            Allow from ${::fqdn}
          </Limit>",
        default => "${_apache_limits}\n"
      },
      notify  => Service['httpd']
    }
  }
  else {
    $_ssl_certificate_file = $ssl_certificate_file
    $_ssl_certificate_key_file = $ssl_certificate_key_file
    $_ssl_ca_certificate_path = $ssl_ca_certificate_path
  }
}
