# This copies pki certificates if required
#
# This module is not called if simp_apache is managing the apache server because
# simp_apache will manage the certificates then.
#
# @param pki
#   * If 'simp', include SIMP's pki module and use pki::copy to manage
#     application certs in /etc/pki/simp_apps/simp_elasticsearch/x509
#   * If true, do *not* include SIMP's pki module, but still use pki::copy
#     to manage certs in /etc/pki/simp_apps/simp_elasticsearch/x509
#   * If false, do not include SIMP's pki module and do not use pki::copy
#     to manage certs.  You will need to appropriately assign a subset of:
#     * app_pki_dir
#     * app_pki_key
#     * app_pki_cert
#     * app_pki_ca
#     * app_pki_ca_dir
#
# @param app_pki_external_source
#   * If pki = 'simp' or true, this is the directory from which certs will be
#     copied, via pki::copy.  Defaults to /etc/pki/simp/x509.
#
#   * If pki = false, this variable has no effect.
#
# @param app_pki_dir
#   This variable controls the basepath of $app_pki_key, $app_pki_cert,
#   $app_pki_ca, $app_pki_ca_dir, and $app_pki_crl.
#   It defaults to /etc/pki/simp_apps/simp_elasticsearch/x509.
#
# @param app_pki_key
#   Path and name of the private SSL key file
#
# @param app_pki_cert
#   Path and name of the public SSL certificate
#
# @param app_pki_ca_dir
#   Path to the CA.
#
# @param group
#   Group for PKI copies
#
# @param owner
#   Owner for PKI copies
#
class simp_elasticsearch::pki(
  Variant[Boolean,Enum['simp']] $pki                     = simplib::lookup('simp_options::pki' , { 'default_value' => false }),
  String                        $app_pki_external_source = simplib::lookup('simp_options::pki::source', { 'default_value' => '/etc/pki/simp/x509' }),
  Stdlib::AbsolutePath          $app_pki_dir             = '/etc/pki/simp_apps/simp_elasticsearch/x509',
  Stdlib::AbsolutePath          $app_pki_cert            = "${app_pki_dir}/public/${facts['fqdn']}.pub",
  Stdlib::AbsolutePath          $app_pki_key             = "${app_pki_dir}/private/${facts['fqdn']}.pem",
  Stdlib::AbsolutePath          $app_pki_ca_dir          = "${app_pki_dir}/cacerts",
  String                        $group                   = 'apache',
  String                        $owner                   = 'root'
){

  if $pki {
    ::pki::copy { 'simp_elasticsearch' :
      source => $app_pki_external_source,
      pki    => $pki,
      owner  => $owner,
      group  => $group,
      notify => Service['httpd']
    }
  }
}
