# Referenced by
# os-ext-testing/puppet/modules/os_ext_testing/manifest/master.pp
# openstack-infra/modules/openstack_project/manifest/jenkins.pp
# openstack-infra/modules/openstack_project/manifest/zuul_dev.pp

class metaplugin_ci::master (
  $vhost_name = $::fqdn,
  $ssl_cert_file_contents = '',
  $ssl_key_file_contents = '',
  $ssl_chain_file_contents = '',
  $jenkins_ssh_private_key = '',
  $jenkins_ssh_public_key = '',
  $log_server = 'localhost',
  $log_url_base = "http://$log_server/metaplugin-ci",
  $upstream_gerrit_server = 'review.openstack.org',
  $gearman_server = '127.0.0.1',
  $upstream_gerrit_user = '',
  $upstream_gerrit_ssh_private_key = '',
  $upstream_gerrit_host_pub_key = '',
  $git_email = 'testing@myvendor.com',
  $git_name = 'MyVendor Jenkins',
  $zuul_url = '',
  $jenkins_url = '',
) {

  include metaplugin_ci::base

  if $ssl_chain_file_contents != '' {
    $ssl_chain_file = '/etc/ssl/certs/intermediate.pem'
  } else {
    $ssl_chain_file = ''
  }

  class { '::jenkins::master':
    vhost_name              => "jenkins",
    logo                    => 'openstack.png',
    ssl_cert_file           => "/etc/ssl/certs/jenkins.pem",
    ssl_key_file            => "/etc/ssl/private/jenkins.key",
    ssl_chain_file          => $ssl_chain_file,
    ssl_cert_file_contents  => $ssl_cert_file_contents,
    ssl_key_file_contents   => $ssl_key_file_contents,
    ssl_chain_file_contents => $ssl_chain_file_contents,
    jenkins_ssh_private_key => $jenkins_ssh_private_key,
    jenkins_ssh_public_key  => $jenkins_ssh_public_key,
  }

  # NOTE: not sure these plugins are necessary.
  #       maybe there are many unnecessary plugins.
  jenkins::plugin { 'ansicolor':
    version => '0.3.1',
  }
  jenkins::plugin { 'build-timeout':
    version => '1.14',
  }
  jenkins::plugin { 'copyartifact':
    version => '1.22',
  }
  jenkins::plugin { 'dashboard-view':
    version => '2.3',
  }
  jenkins::plugin { 'envinject':
    version => '1.70',
  }
  jenkins::plugin { 'gearman-plugin':
    version => '0.0.7',
  }
  jenkins::plugin { 'git':
    version => '1.1.23',
  }
  jenkins::plugin { 'github-api':
    version => '1.33',
  }
  jenkins::plugin { 'github':
    version => '1.4',
  }
  jenkins::plugin { 'greenballs':
    version => '1.12',
  }
  jenkins::plugin { 'htmlpublisher':
    version => '1.0',
  }
  jenkins::plugin { 'extended-read-permission':
    version => '1.0',
  }
  jenkins::plugin { 'zmq-event-publisher':
    version => '0.0.3',
  }
  jenkins::plugin { 'postbuild-task':
    version => '1.8',
  }
  jenkins::plugin { 'violations':
    version => '0.7.11',
  }
  jenkins::plugin { 'jobConfigHistory':
    version => '1.13',
  }
  jenkins::plugin { 'monitoring':
    version => '1.40.0',
  }
  jenkins::plugin { 'nodelabelparameter':
    version => '1.2.1',
  }
  jenkins::plugin { 'notification':
    version => '1.4',
  }
  jenkins::plugin { 'openid':
    version => '1.5',
  }
  jenkins::plugin { 'parameterized-trigger':
    version => '2.15',
  }
  jenkins::plugin { 'publish-over-ftp':
    version => '1.7',
  }
  jenkins::plugin { 'rebuild':
    version => '1.14',
  }
  # NOTE: not released yet. but use 1.9 function. install manually. see below.
  #jenkins::plugin { 'scp':
  #  version => '1.9',
  #}
  jenkins::plugin { 'simple-theme-plugin':
    version => '0.2',
  }
  jenkins::plugin { 'timestamper':
    version => '1.3.1',
  }
  jenkins::plugin { 'token-macro':
    version => '1.5.1',
  }
  jenkins::plugin { 'url-change-trigger':
    version => '1.2',
  }
  jenkins::plugin { 'urltrigger':
    version => '0.24',
  }

  file { '/var/lib/jenkins/.ssh/config':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0640',
    require => File['/var/lib/jenkins/.ssh'],
    source  => 'puppet:///modules/metaplugin_ci/ssh_config',
  }

  # NOTE: install scp plugin 1.9 manually.
  #       this file is get from Ryu CI.
  file { '/var/lib/jenkins/plugins/scp.hpi':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0644',
    require => File['/var/lib/jenkins/plugins'],
    source  => 'puppet:///modules/metaplugin_ci/scp.hpi',
  }

  class { '::jenkins::job_builder':
    url      => $jenkins_url,
    username => 'jenkins',
    password => '',
    git_revision => 'master',
    git_url => 'https://git.openstack.org/openstack-infra/jenkins-job-builder',
    config_dir => 'puppet:///modules/metaplugin_ci/jenkins_job_builder/config',
  }

  file { '/etc/jenkins_jobs/config/macros.yaml':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    content => template('metaplugin_ci/jenkins_job_builder/config/macros.yaml.erb'),
    notify  => Exec['jenkins_jobs_update'],
  }

  file { '/etc/default/jenkins':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/openstack_project/jenkins/jenkins.default',
  }

  class { '::zuul':
    vhost_name           => "zuul",
    gearman_server       => $gearman_server,
    gerrit_server        => $upstream_gerrit_server,
    gerrit_user          => $upstream_gerrit_user,
    zuul_ssh_private_key => $upstream_gerrit_ssh_private_key,
    url_pattern          => "$log_url_base/{build.parameters[LOG_PATH]}",
    zuul_url             => $zuul_url,
    job_name_in_report   => true,
    status_url           => "http://localhost/zuul/status",
    git_email            => $git_email,
    git_name             => $git_name
  }

  class { '::zuul::server':
    layout_dir => 'puppet:///modules/metaplugin_ci/zuul/layout',
  }
  class { '::zuul::merger': }

  file { '/home/zuul/.ssh':
    ensure  => directory,
    owner   => 'zuul',
    group   => 'zuul',
    mode    => '0700',
    require => User['zuul'],
  }

  # NOTE: it is necessary. but why ?
  file { '/home/zuul/.ssh/config':
    ensure  => present,
    owner   => 'zuul',
    group   => 'zuul',
    mode    => '0700',
    require => File['/home/zuul/.ssh'],
    source  => 'puppet:///modules/metaplugin_ci/ssh_config',
  }

  file { '/etc/zuul/logging.conf':
    ensure => present,
    source => 'puppet:///modules/openstack_project/zuul/logging.conf',
    notify => Exec['zuul-reload'],
  }

  file { '/etc/zuul/gearman-logging.conf':
    ensure => present,
    source => 'puppet:///modules/openstack_project/zuul/gearman-logging.conf',
    notify => Exec['zuul-reload'],
  }
  
  file { '/etc/zuul/merger-logging.conf':
    ensure => present,
    source => 'puppet:///modules/openstack_project/zuul/merger-logging.conf',
  }

  class { '::recheckwatch':
    gerrit_server                => $upstream_gerrit_server,
    gerrit_user                  => $upstream_gerrit_user,
    recheckwatch_ssh_private_key => $upstream_gerrit_ssh_private_key,
  }

  file { '/var/lib/recheckwatch/scoreboard.html':
    ensure  => present,
    source  => 'puppet:///modules/openstack_project/zuul/scoreboard.html',
    require => File['/var/lib/recheckwatch'],
  }
}
