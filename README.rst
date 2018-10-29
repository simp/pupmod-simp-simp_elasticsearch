|License| |CII Best Practices| |Puppet Forge| |Puppet Forge Downloads| |Build Status|

SIMP Elasticsearch Puppet Component Module
==========================================

Table of Contents
-----------------

#. `Overview <#overview>`__
#. `Setup - The basics of getting started with simp_elasticsearch <#setup>`__

   -  `What simp_elasticsearch affects <#what-simp_elasticsearch-affects>`__
   -  `Setup requirements <#setup-requirements>`__
   -  `Beginning with simp_elasticsearch <#beginning-with-simp_elasticsearch>`__

      - `Setting up a One Node System <#setting-up-a-one-node-system>`__
      - `Setting up a Multi-Node Cluster <#setting-up-a-multi-node-cluster>`__
      - `Enabling Remote Connections <#enabling-remote-connections>`__

#. `Limitations - OS compatibility, etc. <#limitations>`__
#. `Development - Guide for contributing to the module <#development>`__

   -  `Acceptance Tests - Beaker env variables <#acceptance-tests>`__

Overview
--------

A module to integrate the `upstream elasticsearch module <https://github.com/elastic/puppet-elasticsearch>`__ into the SIMP ecosystem.

This is a SIMP component module
-------------------------------

This module is a component of the `System Integrity Management
Platform <https://simp-project.com>`__, a
compliance oriented framework built on Puppet.

If you find any issues, they can be submitted to our
`JIRA <https://simp-project.atlassian.net/>`__.

As a component module, this module is not recommended for use outside of a SIMP
environment but may work with some minor modification.

Setup
-----

What simp_elasticsearch affects
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This module will install Java on your system and will configure an
Elasticsearch server to be part of a cluster.

An Apache configuration is provided for encrypting external communications to
the Elasticsearch server as well as for restricting the actions that can be
performed on the data therein.

There are numerous advanced settings that may be used and it is recommended
that you read the class headers as well as looking at the acceptance tests for
greater detail.

Setup Requirements
^^^^^^^^^^^^^^^^^^

The only thing necessary to begin using simp_elasticsearch is to install it
into your module path.

Beginning with simp_elasticsearch
---------------------------------

Setting up a One Node System
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Though rarely used in production, this can be good for limited collection and
processing environments that does not have the resources for multi-node
clusters while preserving the analytic and reporting capabilities of larger
systems.

The only item that is required for a single node system is the
`simp_elasticsearch::cluster_name` parameter. Please make this something unique
since it is key to creating Elasticsearch clusters and preventing cluster
cross-talk.

You will need to perform all local communications on local port **9199**.

.. note::
  This will be restricted to communications only on the local system.

In Hiera, you can define this as follows:

.. code:: yaml

  simp_elasticsearch::cluster_name : 'my_cluster'

In addition, for EL6 systems, ensure the correct version of JAVA is
installed as follows:

.. code:: yaml

  java::package : 'java-1.8.0-openjdk-devel'

Setting up a Multi-Node Cluster
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

In most cases, you will want to configure a multi-node cluster to scale as your
data grows. This module is equipped to provide protection for data being
transferred into the system but does not provide protection for data traversing
between Elasticsearch nodes themselves.

If you need to protect data between the Elasticsearch nodes, we recommend using
IPSec which can be configured via the `SIMP IPSec Module`_. The upstream
Elasticsearch module provides support for Shield but this module has not been
tested in that configuration.

.. note::
  You will need to enumerate all of your Elasticsearch cluster hosts to use this module

In keeping with the principle of least privilege, we have designed this module
to restrict communication with the cluster to only those hosts that are
allowed. To this end, you must specify each of the hosts to which you wish to
speak and you must also advertise the correct bind host entry for your cluster
nodes.

For systems with a single interface, the following should suffice.

For systems with multiple interfaces, you will either need to bind to all
interfaces or you will want to create a custom `es_bind_address` fact that you
can use in the place of `::ipaddress` below.

.. code:: yaml

  simp_elasticsearch::cluster_name : 'my_cluster'
  simp_elasticsearch::bind_host : "%{::ipaddress}"
  simp_elasticsearch::unicast_hosts :
    - first.cluster.host:9300
    - second.cluster.host:9300
    - third.cluster.host:9300

Be sure to specify the correct version of JAVA for EL6 systems as follows:

.. code:: yaml

  java::package : 'java-1.8.0-openjdk-devel'

Enabling Remote Connections
^^^^^^^^^^^^^^^^^^^^^^^^^^^

We have wrapped an Apache instance around the Elasticsearch nodes that you wish
to expose to the outside world.

To expose your cluster to external hosts, you will use the following Hiera configuration.

.. code:: yaml

  # This is required for use with Grafana. If you are not using Grafana, you
  # should require client validation (default) if at all possible.
  simp_elasticsearch::simp_apache::ssl_verify_client: 'none'

  simp_elasticsearch::http_method_acl :
    'limits' :
      'hosts' :
        'first.client.system' : 'defaults'
        'second.client.system' : 'defaults'

For full documentation of this format, look into the
`::simp_elasticsearch::apache::defaults` class.

Limitations
-----------

This module has only been tested on Red Hat Enterprise Linux 6 and 7 and CentOS
6 and 7.

Development
-----------

Please read our `Contribution Guide <http://simp-doc.readthedocs.io/en/stable/contributors_guide/index.html>`__.

Acceptance tests
^^^^^^^^^^^^^^^^

To run the system tests, you need
`Vagrant <https://www.vagrantup.com/>`__ installed. Then, run:

.. code:: shell

    bundle exec rake acceptance

Some environment variables may be useful:

.. code:: shell

    BEAKER_debug=true
    BEAKER_provision=no
    BEAKER_destroy=no
    BEAKER_use_fixtures_dir_for_modules=yes

-  ``BEAKER_debug``: show the commands being run on the STU and their
   output.
-  ``BEAKER_destroy=no``: prevent the machine destruction after the
   tests finish so you can inspect the state.
-  ``BEAKER_provision=no``: prevent the machine from being recreated.
   This can save a lot of time while you're writing the tests.
-  ``BEAKER_use_fixtures_dir_for_modules=yes``: cause all module
   dependencies to be loaded from the ``spec/fixtures/modules``
   directory, based on the contents of ``.fixtures.yml``. The contents
   of this directory are usually populated by
   ``bundle exec rake spec_prep``. This can be used to run acceptance
   tests to run on isolated networks.

.. _SIMP IPSec Module: https://github.com/simp/pupmod-simp-libreswan
.. |License| image:: http://img.shields.io/:license-apache-blue.svg
   :target: http://www.apache.org/licenses/LICENSE-2.0.html
.. |CII Best Practices| image:: https://bestpractices.coreinfrastructure.org/projects/73/badge
   :target: https://bestpractices.coreinfrastructure.org/projects/73
.. |Puppet Forge| image:: https://img.shields.io/puppetforge/v/simp/simp_elasticsearch.svg
   :target: https://forge.puppetlabs.com/simp/simp_elasticsearch
.. |Puppet Forge Downloads| image:: https://img.shields.io/puppetforge/dt/simp/simp_elasticsearch.svg
   :target: https://forge.puppetlabs.com/simp/simp_elasticsearch
.. |Build Status| image:: https://travis-ci.org/simp/pupmod-simp-simp_elasticsearch.svg
   :target: https://travis-ci.org/simp/pupmod-simp-simp_elasticsearch
