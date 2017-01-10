# This copies pki certificates if required
#
#  This module is not called if simp_apache is managing the apache server because
#  simp_apache will manage the certificates then.
#
#  @param pki  If false you must set the app_pki_[cert,key,ca_dir] variables for
#  this module else it will copy the certs from app_pki_external_source to app_pki_dir
#  and set those variables as defined in pki::copy.
#
class simp_elasticsearch::pki(
  Variant[Boolean,Enum['simp']] $pki               = simplib::lookup('simplib_options::pki' , { 'default_value' => false }),
  Stdlib::AbsolutePath          $app_pki_cert      = "/etc/pki/simp/public/${facts['fqdn']}.pub",
  Stdlib::AbsolutePath          $app_pki_key       = "/etc/pki/simp/private/${facts['fqdn']}.pem",
  Stdlib::AbsolutePath          $app_pki_ca_dir    = '/etc/pki/simp/cacerts',
  Stdlib::AbsolutePath          $app_pki_dir       = '/etc/pki/elasticsearch',
  Stdlib::AbsolutePath          $app_pki_external_source = simplib::lookup('simplib_options::app_pki_external_source',{ 'default_value' => '/etc/pki/simp'}),
  String                        $group             = 'apache',
  String                        $owner             = 'root'
){

  if $pki {

    ::pki::copy { $app_pki_dir :
      source => $app_pki_external_source,
      pki    => $pki,
      owner  => $owner,
      group  => $group,
      notify => $::simp_elasticsearch::http_service_resource
    }

    $app_pki_cert = "${app_pki_dir}/public/${::fqdn}.pub"
    $app_pki_key  = "${app_pki_dir}/public/${facts['fqdn']}.pem"
    $app_pki_ca_cert = "${app_pki_dir}/cacerts"

  } else {

    file { [ $app_pki_cert, $app_pki_key ] :
      ensure => file,
      mode   => '0640',
      owner  => $owner,
      group  => $group
    }

    file { $app_pki_ca_dir :
      ensure => directory,
      mode   => '0640',
      owner  => $owner,
      group  => $group
    }
  }
}
