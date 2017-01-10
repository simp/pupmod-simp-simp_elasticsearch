# This class integrates the electrical-elasticsearch module with the
# configuration settings recommended for SIMP systems.
#
# Please use the portions that make sense for your environment.
#
# The classes are separated in such a way as to be usable individually where
# possible.
#
# At this time, it is NOT possible to encrypt data across the ES transport
# mechanism. The http interface is optionally fronted with Apache and encrypted
# that way.
#
# We are planning to move to add IPSec support in the future so that the
# transport layer can be optionally protected internally.
#
# Currently, an IPTables rule is created for each host that you add to your
# unicast hosts list. We will be moving to use ipset in the future for
# optimization.
#
# @param cluster_name *Required* The name of the cluster that this
#   node will be joining.
#
# @param replicas The number of replicas for the ES cluster.
#
# @param shards The number of shards for the ES cluster.
#
# @param node_name An arbitrary, unique name fo this node.
#
# @param bind_host The IP address to which to bind the cluster
#   communications service.
#
#   @note Do NOT set this to 127.0.0.1 unless you *really* know what you are
#     doing.
#
# @param http_bind_host The IP address to which to bind the http
#   service.
#
#   @note Do NOT set this to 127.0.0.1 unless you *really* know what you are
#     doing.
#
# @param http_port This port will be exposed for http interactions into
#   the ES engine.
#
#   @note This will *not* be exposed directly through iptables unless set to
#     9200. 9200 is the ES default so setting this to *anything else* means
#     that you want to proxy and to not expose this port to the world.
#
# @param http_method_acl This controls the remote accesses allowed to
#   ES. This is quite complex and you should check the documentation carefully
#   prior to proceeding.
#
#     @see simp_elasticsearch::apache option 'method_acl'
#
# @param https_trusted_nets This is an array of IPs/hosts to
#   allow to connect to the https service. If you're using ES for LogStash,
#   then all clients that should be able to connect to this node in order to
#   store data into ES should be allowed.
#
# @param data_dir The path where the data should be stored.  You
#   will need to create all parent directories, this module will not do it for
#   you.
#
# @param min_master_nodes The number of master nodes that consitutes
#   an operational cluster.
#
#   @note If fewer than 3 unicast hosts are specified below, this will default
#     to 1.
#
# @param unicast_hosts We do not support multicast joining
#   for security reasons. You must specify all of your hosts here.
#
#   @note It not recommended to change this default unless you have a different
#     Hiera variable that you are using.
#
# @param init_defaults Options that will be passed directly into
#   /etc/sysconfig/elasticsearch. Anything passed in via this hash will be
#   merged with the default hash.
#
# @param es_config Options as required by the 'elasticsearch'
#   module.  If you specify your own hash, then it will be merged with the
#   default.
#
# @param max_log_days The number of days of elasticsearch logs to keep
#   on the system.
#
#   @note This will *not* remove files by size so watch your cluster disk space
#     in /var/log.
#
# @param manage_httpd Whether or not to manage the httpd configuration
#   on this system.
#
#   May be One of `true`, `false`, or 'conf'
#     * true  => Manage the entire web stack.
#     * false => Manage nothing.
#     * conf  => Just drop the configuration file into /etc/httpd/conf.d
#       note:  conf assumes you have apache installed and that Service['httpd'] exists
#              somewhere in the catalog.
#
# @param restart_on_change Whether or not to restart on a
#   configuration change.
#
# @param firewall Whether or not to use iptables for ES
#   connections.
#
# @param spawn_default_instance  If set, create a default instance,
#   named 'simp', on the system.
#
# @example Local ES instance
#
# # Set up an ES instance that will only run on this server.
# # No entry added to the extdata directory
#
# class { 'simp_elasticsearch': cluster_name => 'single' }
#
# @example Clustered ES instance
#
# # Set up an ES instance that will act as part of a larger cluster.
# # An entry in Hiera must be set to the following:
# FIXME
# # simp_elasticsearch,"<ip_address_one>","<ip_address_two>"
#
# class { 'simp_elasticsearch':
#   cluster_name        => 'multi',
#   number_of_replicas  => 2,
#   number_of_shards    => 8
# }
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
# @copyright 2016 Onyx Point, Inc.
class simp_elasticsearch (
  String                          $cluster_name,
  Simplib::Host                   $node_name              = $facts['fqdn'],
  Integer[0]                      $replicas               = 1,
  Integer[0]                      $shards                 = 5,
  Simplib::Host                   $bind_host              = $facts['ipaddress'],
  Simplib::Host                   $http_bind_host         = '127.0.0.1',
  Simplib::Port                   $http_port              = 9199,
  Hash                            $http_method_acl        = {},
  Stdlib::AbsolutePath            $data_dir               = '/var/elasticsearch',
  Integer[0]                      $min_master_nodes       = 2,
  Array[Simplib::Host::Port]      $unicast_hosts          = ["${facts['fqdn']}:9300"],
  Hash[Pattern['^[A-Z,_]+$'],Any] $init_defaults          = {},
  Data                            $es_config              = {},
  Numeric                         $max_log_days           = 7,
  String                          $max_locked_memory      = '',
  String                          $max_open_files         = '',
  Variant[Boolean,Enum['conf']]   $manage_httpd           = true,
  Simplib::NetList                $https_trusted_nets     = ['127.0.0.1'],
  Boolean                         $restart_on_change      = true,
  Boolean                         $firewall               = simplib::lookup('simp_options::firewall', { 'default_value' => false}),
  Boolean                         $install_unix_utils     = true,
  Boolean                         $spawn_default_instance = true,
) {
  include '::simp_elasticsearch::defaults'
  include '::pam::limits'

  if !empty($es_config) {
    $_config = deep_merge($::simp_elasticsearch::defaults::base_config,$es_config)
  }
  else {
    $_config = $::simp_elasticsearch::defaults::base_config
  }

  if $spawn_default_instance {
    include '::simp_elasticsearch::default_instance'

    Class['simp_elasticsearch'] -> Class['simp_elasticsearch::default_instance']
  }

  include '::java'

  # TODO: Figure out how to move this into a single include!
  class { 'elasticsearch':
    config            => $_config,
    autoupgrade       => true,
    status            => 'enabled',
    init_defaults     => deep_merge(
      $init_defaults,
      $::simp_elasticsearch::defaults::init_defaults
    ),
    datadir           => "${data_dir}/data",
    restart_on_change => $restart_on_change
  }

  Class['java'] -> Class['elasticsearch']

  file { '/etc/cron.daily/elasticsearch_log_purge':
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => "#!/bin/sh
if [ -d /var/log/elasticsearch ]; then
  /bin/find /var/log/elasticsearch -type f -mtime +${max_log_days} -exec /bin/rm {} \\;
fi
"
  }

  # Correct the permissions on the ES templates directory
  file { '/etc/elasticsearch/templates_import':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  file { $_config['path.data']:
    ensure  => 'directory',
    owner   => 'elasticsearch',
    group   => 'elasticsearch',
    require => Package['elasticsearch']
  }

  # This is here due to some weird bug in ES that won't read /etc properly.
  file { '/usr/share/elasticsearch/config':
    ensure => 'symlink',
    target => '/etc/elasticsearch',
    force  => true
  }

  if $firewall {
    include '::iptables'

    iptables_rule { 'elasticsearch_allow_cluster':
      first   => true,
      content => es_iptables_format($_config['discovery']['zen']['ping']['unicast']['hosts'])
    }
  }

  if $manage_httpd or $manage_httpd == 'conf' {
    class { 'simp_elasticsearch::simp_apache':
      manage_httpd => $manage_httpd,
      proxyport    => $_config['http']['port'],
      method_acl   => $http_method_acl,
    }
  }

  if $manage_httpd {
    # Allow remote connections
    if $firewall {
      if !empty($http_method_acl) {
        $_macl_limits = $http_method_acl['limits']
        if defined('$_macl_limits') and !empty($_macl_limits) {
          $_macl_hosts = $_macl_limits['hosts']
          if defined('$_macl_hosts') and !empty($_macl_hosts) {
            iptables::listen::tcp_stateful{ 'elasticsearch_allow_remote':
              trusted_nets => keys($_macl_hosts),
              dports       => [ 9200 ]
            }
          }
        }
      }
    }
  }

  pam::limits::rule { 'es_heap_sizelock':
    domains => ['elasticsearch'],
    type    => '-',
    item    => 'memlock',
    value   => 'unlimited',
    order   => 0,
  }
}
