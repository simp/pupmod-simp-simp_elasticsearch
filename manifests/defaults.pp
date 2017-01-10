# This class is just for storing default option hashes so the the main
# classes are cleaner.
#
# Items are called from simp_elasticsearch
#
class simp_elasticsearch::defaults {

  if array_size($::simp_elasticsearch::unicast_hosts) < 3 {
    $min_master_nodes = 1
  }
  else {
    $min_master_nodes = $::simp_elasticsearch::min_master_nodes
  }

  if empty($::simp_elasticsearch::init_defaults['es_heap_size']) {
    $mem_bytes = to_bytes($::memorysize)

    if $mem_bytes < 4294967296 {
      $es_heap_size = ( $mem_bytes / 2 )
    }
    else {
      $es_heap_size = (( $mem_bytes / 2 ) + 2147483648 )
    }
  }

  $init_defaults = {
    'ES_USER'      => 'elasticsearch',
    'ES_GROUP'     => 'elasticsearch',
    # The amount of memory that ES should allocate on startup.
    #   Default: 50% of Memory + 2G. If < 4G is present, just 50% of
    #   mem.
    'ES_HEAP_SIZE' => $es_heap_size
  }

  $base_config = {
    'cluster'     => {
      'name'                => $::simp_elasticsearch::cluster_name
    },
    'node.name'   => $::simp_elasticsearch::node_name,
    'index'       => {
      'number_of_replicas'  => $::simp_elasticsearch::replicas,
      'number_of_shards'    => $::simp_elasticsearch::shards
    },
    'network'     => {
      'bind_host'    => $::simp_elasticsearch::bind_host,
      # This must be done due to a bug in the ES configuration processor that
      # does not match the documentation which states that publish_host will be
      # automatically selected from the best address in bind_host.
      'publish_host' => $::simp_elasticsearch::bind_host
    },
    'http'        => {
      'bind_host' => $::simp_elasticsearch::http_bind_host,
      'port'      => $::simp_elasticsearch::http_port
    },
    'path.logs'   => '/var/log/elasticsearch',
    'path.data'   => $::simp_elasticsearch::data_dir,
    'discovery'                => {
      'zen'                    => {
        'minimum_master_nodes' => $min_master_nodes,
        'ping'                 => {
          'multicast'          => {
            'enabled'          => false
          },
          'unicast' => {
            'hosts' => $::simp_elasticsearch::unicast_hosts
          }
        }
      }
    }
  }
}
