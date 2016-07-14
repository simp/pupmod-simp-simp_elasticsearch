# Spawn a default elasticsearch instance on the system
#
# @private
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
# @copyright 2016 Onyx Point, Inc.
#
class simp_elasticsearch::default_instance {
  elasticsearch::instance{ 'simp': }
}
