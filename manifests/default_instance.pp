# Spawn a default elasticsearch instance on the system
#
# @private
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class simp_elasticsearch::default_instance {
  include '::simp_elasticsearch'
  assert_private()
  elasticsearch::instance{ $::simp_elasticsearch::default_instance_name: }
}
