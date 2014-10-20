# A Jenkins slave that will execute jobs that use devstack
# to set up a full OpenStack environment for test runs.

class metaplugin_ci::slave (
  $ssh_key = '',
  $this_dir = '',
) {
  include metaplugin_ci::base
  include openstack_project::tmpcleanup

  class { 'jenkins::slave':
    ssh_key => $ssh_key,
    user    => true,
    python3 => false,
  }

  class { 'openstack_project::slave_common':
    sudo =>         true,
    include_pypy => false,
  }

  # TODO: fix revision to certain commit id
  vcsrepo { '/opt/devstack-gate':
    ensure   => present,
    provider => git,
    revision => 'master',
    source   => 'https://git.openstack.org/openstack-infra/devstack-gate',
  }

  file { '/opt/metaplugin-ci':
    ensure => link,
    target => "$this_dir/metaplugin-ci",
  }

  file { '/etc/rc.local':
    ensure => present,
    source => 'puppet:///modules/metaplugin_ci/etc/rc.local',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  package { 'rabbitmq-server':
    ensure  => present,
    require => File['/etc/rabbitmq/rabbitmq-env.conf'],
  }

  file { '/etc/rabbitmq':
    ensure => directory,
  }

  file { '/etc/rabbitmq/rabbitmq-env.conf':
    ensure  => present,
    group   => 'root',
    mode    => '0444',
    owner   => 'root',
    require => File['/etc/rabbitmq'],
    source  => 'puppet:///modules/devstack_host/rabbitmq-env.conf',
  }
}
