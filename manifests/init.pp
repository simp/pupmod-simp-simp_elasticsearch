# This class integrates the elastic-elasticsearch module with
# the configuration settings recommended for SIMP systems.
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
# Currently, an IPTables rules are created for both ES API and cluster
# communications.  We will be moving to use ipset in the future for
# optimization.
#
# @param cluster_name *Required* The name of the cluster that this
#   node will be joining.
#
# @param node_name An arbitrary, unique name for this node.
#
# @param bind_host The IP address to which to bind the ES cluster
#   communications service.
#
#   @note When set to 127.0.0.1 no cluster communication with external
#     nodes is possible.
#
# @param http_bind_host The IP address to which to bind the ES http
#   service used for ES API communications.
#
#   @note For the most secure http configuration, leave this set to
#     127.0.0.1, set http_listen_port to a value different from 
#     http_port, and set http_method_acl with appropriate 
#     authentication and/or command restrictions.  This will proxy
#     http interactions received on the http_listen_port into the
#     ES engine on http_port, after applying the authentication
#     and/or command restrictions specified in http_method_acl.
#
# @param http_listen_port The port to which secure, external ES
#   API requests should be made. The Apache service will
#   authenticate requests on this port and then proxy them to 
#   http_port on http_bind_host.
#
# @param http_port The port used for http API requests into the ES engine.
#
#   @note This will *not* be exposed directly through iptables unless
#     set to http_listen_port.
#
# @param http_timeout  Default timeout (in seconds) to use when accessing
#     Elasticsearch APIs.
#
# @param http_method_acl This controls the remote accesses allowed to
#   ES. This is quite complex and you should check the documentation carefully
#   prior to proceeding.
#
#     @see simp_elasticsearch::apache option 'method_acl'
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
# @param unicast_hosts You must specify all of your hosts here.
#
# @param init_defaults Options that will be passed directly into
#   the sysconfig file for the elasticsearch service.
#
# @param jna_tmpdir  JNA tmpdir to be used in lieu of /tmp.  Cannot be on a
#   noexec filesystem.  Directory will be created and configured, but
#   you must ensure the parent directory exists and is accessible to
#   the ES user.
#
# @param jvm_options JVM options to be persisted to /etc/elasticsearch/jvm.options.
#   Anything passed in via this array will be appended to the default options.
#
# @param es_config Options as required by the 'elasticsearch'
#   module.  If you specify your own hash, then it will be merged with the
#   default.
#
# @param file_rolling_type Configuration for the file appender rotation.
#   It can be 'dailyRollingFile' to rotate by name or 'rollingFile' to
#   to rotate by name by size.
#
# @param daily_rolling_date_pattern File pattern for the file appender
#   log when file_rolling_type is 'dailyRollingFile'.
#
# @param rolling_file_max_backup_index Max number of logs to store when
#   file_rolling_type is 'rollingFile'.
#
# @param rolling_file_max_file_size Max log file size when file_rolling_type
#    is 'rollingFile'.
#
# @param manage_httpd Whether to manage the httpd configuration
#   on this system.
#
#   May be One of `true`, `false`, or 'conf'
#     * true  => Manage the entire web stack.
#     * false => Manage nothing.
#     * conf  => Just drop the configuration file into /etc/httpd/conf.d
#       note:  conf assumes you have apache installed and that Service['httpd'] exists
#              somewhere in the catalog.
#
# @param restart_on_change  Whether to automatically restart ES whenever the
#   configuration, package, or plugins change. This may be undesireable in
#   highly available environments.  If all other restart_* parameters are
#   left unset, the value of restart_on_change is used for all other
#   restart_*_change defaults.
#
# @param restart_config_change  Whether to automatically restart ES
#   whenever the configuration changes. Disabling automatic restarts on
#   config changes may be desired in an environment where you need to
#   ensure restarts occur in a controlled/rolling manner rather than
#   during a Puppet run.
#
# @param restart_package_change  Whether to automatically restart ES
#   whenever the package (or package version) for ES changes.  Disabling
#   automatic restarts on package changes may be desired in an
#   environment where you need to ensure restarts occur in a
#   controlled/rolling manner rather than during a Puppet run.
#
# @param restart_plugin_change  Whether to automatically restart ES
#   whenever plugins are installed or removed.  Disabling automatic
#   restarts on plugin changes may be desired in an environment where
#   you need to ensure restarts occur in a controlled/rolling manner
#   rather than during a Puppet run.
#
# @param firewall Whether to use iptables for ES http connections
#   and cluster communications.
#
# @param spawn_default_instance  If set, create a default ES instance,
#   named for the cluster, on the system.
#
# @example Local ES instance EL7
#
# # Set up an ES instance that will only run on this server.
#
# class { 'simp_elasticsearch': cluster_name => 'single' }
#
# @example Clustered ES instance EL7
#
# # Set up an ES instance that will act as part of a larger cluster.
#
# class { 'simp_elasticsearch':
#   cluster_name  => 'multi',
#   unicast_hosts => {
#    'first.cluster.host:9300',
#    'second.cluster.host:9300',
#    'third.cluster.host:9300',
#   },
# }
#
# @example ES instance on EL6
#
# In addition to the class definitions listed in the EL7 examples,
# the following hieradata setting is required to ensure the
# correct version of JAVA is installed:
#
# java::package : 'java-1.8.0-openjdk-devel'
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class simp_elasticsearch (
  String                          $cluster_name,
  Simplib::Host                   $node_name              = $facts['fqdn'],
  Simplib::Host                   $bind_host              = $facts['ipaddress'],
  Simplib::Host                   $http_bind_host         = '127.0.0.1',
  Simplib::Port                   $http_listen_port       = 9200,
  Simplib::Port                   $http_port              = 9199,
  Integer                         $http_timeout           = 10,
  Hash                            $http_method_acl        = {},
  Stdlib::AbsolutePath            $data_dir               = '/var/elasticsearch',
  Integer[0]                      $min_master_nodes       = 2,
  Array[Simplib::Host::Port]      $unicast_hosts          = ["${facts['fqdn']}:9300"],
  Hash[Pattern['^[A-Z,_]+$'],Any] $init_defaults          = {},
  Stdlib::AbsolutePath            $jna_tmpdir             = '/var/lib/elasticsearch/tmp',
  Array[Pattern['^-']]            $jvm_options            = [],
  Enum['dailyRollingFile',
    'rollingFile']                $file_rolling_type             = 'dailyRollingFile',
  String                          $daily_rolling_date_pattern    = '"\'.\'yyyy-MM-dd"',
  Integer                         $rolling_file_max_backup_index = 1,
  String                          $rolling_file_max_file_size    = '10MB',
  Data                            $es_config              = {},
  Variant[Boolean,Enum['conf']]   $manage_httpd           = true,
  Boolean                         $restart_on_change      = true,
  Optional[Boolean]               $restart_config_change  = undef,
  Optional[Boolean]               $restart_package_change = undef,
  Optional[Boolean]               $restart_plugin_change  = undef,
  Boolean                         $firewall               = simplib::lookup('simp_options::firewall', { 'default_value' => false}),
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
    $default_instance_name = simp_elasticsearch::systemd_escape($cluster_name)
    include '::simp_elasticsearch::default_instance'

    Class['simp_elasticsearch'] -> Class['simp_elasticsearch::default_instance']
    $_service_name = "elasticsearch-${default_instance_name}.service"
  }
  else {
    $_service_name = 'elasticsearch.service'
  }


  include '::java'

  # TODO: Figure out how to move this into a single include!
  class { 'elasticsearch':
    config                        => $_config,
    autoupgrade                   => true,
    status                        => 'enabled',
    init_defaults                 => $init_defaults,
    jvm_options                   => concat(
      $::simp_elasticsearch::defaults::jvm_options_defaults,
      $jvm_options
    ),
    datadir                       => "${data_dir}/data",
    restart_on_change             => $restart_on_change,
    restart_config_change         => $restart_config_change,
    restart_package_change        => $restart_package_change,
    restart_plugin_change         => $restart_plugin_change,
    file_rolling_type             => $file_rolling_type,
    daily_rolling_date_pattern    => $daily_rolling_date_pattern,
    rolling_file_max_backup_index => $rolling_file_max_backup_index,
    rolling_file_max_file_size    => $rolling_file_max_file_size,
    api_host                      => $http_bind_host,
    api_port                      => $http_port,
    api_timeout                   => $http_timeout
  }

  Class['java'] -> Class['elasticsearch']

  # Tweak elasticsearch installation for SIMP
  include '::simp_elasticsearch::config'

  Class['elasticsearch'] -> Class['simp_elasticsearch::config']

  if $firewall {
    include '::iptables'

    iptables_rule { 'elasticsearch_allow_cluster':
      first   => true,
      content => simp_elasticsearch::iptables_format($_config['discovery']['zen']['ping']['unicast']['hosts'])
    }
  }

  if $manage_httpd or $manage_httpd == 'conf' {
    class { 'simp_elasticsearch::simp_apache':
      manage_httpd => $manage_httpd,
      listen       => $http_listen_port,
      proxy_port   => $_config['http']['port'],
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
              dports       => [ $http_listen_port ]
            }
          }
        }
      }
    }
  }

  # Make sure elasticsearch user can spawn up to 2048 threads
  if ($facts['os']['release']['major'] < '7') {
    # see man page for limits.conf
    pam::limits::rule { 'es_nproc':
      domains => [ $::elasticsearch::elasticsearch_user ],
      item    => 'nproc',
      value   => 2048,
    }
  }
  else {
    # see man page for systemd.unit
    $_systemd_opts_dir = "/etc/systemd/system/${_service_name}.d"
    file { $_systemd_opts_dir:
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
    }

    file { "${_systemd_opts_dir}/opts.conf":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => file("${module_name}/opts.conf"),
      require => File[$_systemd_opts_dir]
    }
  }
}
