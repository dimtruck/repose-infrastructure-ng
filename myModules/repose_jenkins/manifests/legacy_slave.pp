class repose_jenkins::legacy_slave {

  include repose_jenkins::slave

  package { 'openjdk-7-jdk':
      ensure => latest,
  }

  class{"repose_maven":
    user      => 'jenkins',
    user_home => "${repose_jenkins::jenkins_home}",
    require   => User["jenkins"],
  }

  # anything that's going to run jenkins stuff will need rpm
  package { 'rpm':
    # I don't think we care about the version here...
    ensure => present,
  }

  package { 'expect':
    # This is needed by the rpm-maven-plugin
    ensure => present,
  }

  package { 'dpkg-sig':
    # This is needed by the jdeb maven plugin
    ensure => present,
  }

}
