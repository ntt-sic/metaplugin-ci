# Referenced by
# os-ext-testing/modules/os_ext_testing/manifest/base.pp
# openstack-infra/config/modules/openstack_project/manifests/base.pp

class metaplugin_ci::base(
  $certname = $::fqdn,
) {
  include apt
  include ssh
  include snmpd
  include ntp
  include sudoers

  $packages = ['git', 'puppet', 'wget', 'strace', 'tcpdump']
  $update_pkg_list_cmd = 'apt-get update >/dev/null 2>&1;'

  package { $packages:
    ensure => present
  }

  # Custom rsyslog config to disable /dev/xconsole noise on Debuntu servers
  file { '/etc/rsyslog.d/50-default.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  =>
      'puppet:///modules/openstack_project/rsyslog.d_50-default.conf',
    replace => true,
    notify  => Service['rsyslog'],
  }

  # Ubuntu installs their whoopsie package by default, but it eats through
  # memory and we don't need it on servers
  package { 'whoopsie':
    ensure => absent,
  }

  # Increase syslog message size in order to capture
  # python tracebacks with syslog.
  file { '/etc/rsyslog.d/99-maxsize.conf':
    ensure  => present,
    # Note MaxMessageSize is not a puppet variable.
    content => '$MaxMessageSize 6k',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Service['rsyslog'],
  }

  service { 'rsyslog':
    ensure     => running,
    enable     => true,
    hasrestart => true,
  }

  include pip
  $desired_virtualenv = '1.11.4'

  if (( versioncmp($::virtualenv_version, $desired_virtualenv) < 0 )) {
    $virtualenv_ensure = $desired_virtualenv
  } else {
    $virtualenv_ensure = present
  }
  package { 'virtualenv':
    ensure   => $virtualenv_ensure,
    provider => pip,
    require  => Class['pip'],
  }

  # Pin puppet 3.
  $pin_puppet = '3.'
  $pin_facter = '2.'
  $pin_puppetdb = '2.'

  apt::source { 'puppetlabs':
    location   => 'http://apt.puppetlabs.com',
    repos      => 'main',
    key        => '4BD6EC30',
    key_server => 'pgp.mit.edu',
  }

  file { '/etc/apt/apt.conf.d/80retry':
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    source  => 'puppet:///modules/openstack_project/80retry',
    replace => true,
  }

  file { '/etc/apt/preferences.d/00-puppet.pref':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('openstack_project/00-puppet.pref.erb'),
    replace => true,
  }

  file { '/etc/default/puppet':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    source  => 'puppet:///modules/openstack_project/puppet.default',
    replace => true,
  }

  $puppet_version = $pin_puppet
  file { '/etc/puppet/puppet.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('openstack_project/puppet.conf.erb'),
    replace => true,
  }

  service { 'puppet':
    ensure => stopped,
  }

  if (!defined(Vcsrepo['/etc/project-config'])) {
    vcsrepo { '/etc/project-config':
      ensure   => latest,
      provider => git,
      revision => 'master',
      source   => 'https://git.openstack.org/openstack-infra/project-config',
    }
  }
}
