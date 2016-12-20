# This class exists to provide some default settings that can be merged into
# other hashes within the simp_elasticsearch::apache class
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
# @copyright 2016 Onyx Point, Inc.
#
class simp_elasticsearch::simp_apache::defaults {

  $_base_dn = hiera('simp_options::ldap::base_dn','')

  if empty($_base_dn) {
    $_ldap_search = ''
  }
  else {
    $_ldap_search = "ou=People,${_base_dn}"
  }

  $method_acl = {
    'method' => {
      # Use an htdigest file for access control
      'file' => {
        'enable'    => false,
        'user_file' => '/etc/httpd/conf.d/elasticsearch/.htdigest'
      },
      # Use LDAP for access control
      'ldap'    => {
        'enable'      => false,
        'url'         => hiera('simp_options::ldap::uri',''),
        'security'    => 'STARTTLS',
        'binddn'      => hiera('simp_options::ldap::bind_dn',''),
        'bindpw'      => hiera('simp_options::ldap::bind_pw',''),
        'search'      => $_ldap_search,
        'posix_group' => true
      }
    },
    # Set limits on what different hosts can do
    'limits'  => {
      # The allowed operations, default to reasonably safe operations
      'defaults'  => [ 'GET', 'POST', 'PUT' ],
      # The hosts that are allowed to use the remote operations
      # If the RHS is set to 'defaults' then use the 'defaults' entry above,
      # otherwise, this can be set to an array of Apache-allowed web
      # operations.
      #
      # In general, this would be GET, POST, PUT, DELETE, HEAD, and OPTIONS
      'hosts'  => {
        '127.0.0.1'    => 'defaults',
        $facts['fqdn'] => 'defaults'
      }
    }
  }
}
