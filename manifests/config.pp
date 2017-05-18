# This class makes adjustments to files/system parameters
# used by for the elasticsearch service, so that this
# service can run in a SIMP environment.
#
class simp_elasticsearch::config {
  assert_private()
  # Correct the permissions on the ES templates directory
  # TODO Verify this workaround is still required.
  file { '/etc/elasticsearch/templates_import':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }

  file { $::elasticsearch::config['path.data']:
    ensure  => 'directory',
    owner   => $::elasticsearch::elasticsearch_user,
    group   => $::elasticsearch::elasticsearch_group,
    require => Package['elasticsearch']
  }

  # This is here due to some weird bug in ES that won't read /etc properly.
  # TODO Verify this workaround is still required.
  file { '/usr/share/elasticsearch/config':
    ensure => 'symlink',
    target => '/etc/elasticsearch',
    force  => true
  }

  pam::limits::rule { 'es_heap_sizelock':
    domains => [ $::elasticsearch::elasticsearch_user ],
    type    => '-',
    item    => 'memlock',
    value   => 'unlimited',
    order   => 0,
  }

  # Out-of-the-box, ES will not start in a SIMP environment because
  # JNA is configured to use /tmp as its tmpdir and /tmp is set to
  # noexec.  We can configure the JNA directory via JVM options,
  # but, this causes ES to core unless the ES user's home directory
  # exists. Unfortunately, that directory is set to /home/elasticsearch
  # when the ES user is created in the elasticsearch RPM post-install.
  # This directory is not universally appropriate (e.g. when /home
  # is a NFS-mounted system), so to solve the JNA problem, we need
  # to both set the JNA tmpdir JVM option (see
  # simp_elasticsearch::jvm_options_defaults) and change the ES user
  # home directory to one more suitable for a service.

  # Change the home directory
  user {  $::elasticsearch::elasticsearch_user:
    ensure  => 'present',
    comment => 'elasticsearch user',
    home    => '/var/local/elasticsearch',
    shell   => '/sbin/nologin',
    system  => true
  }

  # Make sure directory exists
  # NOTE:  Can't do this in the user resource above, because setting the
  # 'managehome' attribute to true won't create the directory for a user
  # that already exists.
  file { '/var/local/elasticsearch':
    ensure => 'directory',
    group  =>  $::elasticsearch::elasticsearch_group,
    owner  =>  $::elasticsearch::elasticsearch_user,
    mode   => '0770',
  }

  # Create tmp directory for JNA
  #TODO set up systemd-tmpfiles/tmpwatch rule for this dir, if needed
  file { $::simp_elasticsearch::jna_tmpdir:
    ensure  => 'directory',
    group   =>  $::elasticsearch::elasticsearch_group,
    owner   =>  $::elasticsearch::elasticsearch_user,
    mode    => '0770',
    seltype => 'tmp_t',
  }

}
