# Installs base layer, but no jenkins itself. Perfect for a slave configuration.
# also used by the master, basically anything that wants to run our jenkins jobs
# Depends on garethr/remotesyslog to activate remote syslog for things on this host
class repose_jenkins(
    $maven_version = "3.2.1",
    $deploy_key = undef,
    $deploy_key_pub = undef,
    $inova_username = undef,
    $inova_password = undef,
    $research_nexus_username = undef,
    $research_nexus_password = undef
) {

    # ensure maven is installed
    # see https://forge.puppetlabs.com/maestrodev/maven for many examples, including how to set up ~/.m2/settings.xml
    class{"maven::maven":
        version => "${maven_version}",
    }

    $jenkins_home = '/var/lib/jenkins'

    # specify some maven options for jenkins
    # had to specify the user home, because it doesn't facter it :|
    maven::environment {'maven-jenkins':
        user => 'jenkins',
        home => "${jenkins_home}",
        maven_opts => '-Xms512m -Xmx1024m -XX:PermSize=256m -XX:MaxPermSize=512m -XX:-UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled',
        require => [
            User["jenkins"],
            Class['java']
        ],
    }

    # adding a symlink to make other things happier
    # the jenkins config relies on a simple /opt/maven symlink to whatever version of mave is installed
    # easy to type, easy to implement
    file{"/opt/maven":
        ensure => link,
        target => "/opt/apache-maven-${maven_version}",
        require => Class['java'],
    }

    # this should ensure we've got java on the system at jdk7. Installed via package
    # it will give us JDK7 however.
    # this is really stupid, for some reason it can't pick up the proper package version
    # and is doing stupid things, so I have to tell it everything basically.
    # the example42 one is more reliable, but I can't use it because it conflicts.
    # this will get us whatever the latest version is at the time
    # I don't know why it doesn't work like it's supposed to :|
    # I'm really only using it at this point because the rtyler/jenkins module wants it :|
    class{'java':
        distribution => 'jdk',
        package => 'openjdk-7-jdk',
        version => 'present',
    }

    # anything that's going to run jenkins stuff will need rpm
    package { 'rpm':
        # I don't think we care about the version here...
        ensure => present,
    }

    package {'git':
        ensure => present,
    }

    #jenkins master needs a git config so that it can talk to the scm plugin
    # Also needed by any of the release builds for when they do a git push
    file{"${jenkins_home}/.gitconfig":
        ensure => file,
        mode => 0664,
        owner => jenkins,
        group => jenkins,
        source => "puppet:///modules/repose_jenkins/jenkins-gitconfig",
    }

    group {'jenkins':
        ensure => present,
    }

    user {'jenkins':
        ensure     => present,
        gid        => 'jenkins',
        home       => $jenkins_home,
        shell      => '/bin/bash',
        managehome => true,
    }

    ssh_authorized_key {'jenkins':
        ensure  => present,
        type    => 'ssh-rsa',
        key     => 'AAAAB3NzaC1yc2EAAAADAQABAAABAQDRLK7eHYRbfj/NgIUlc8ECZD9EFwvj4ZvQDrkMX+4HBcpvQr6vVvQlezx7qtCnpZtPYbQvp0udxsfU9+ESlBMGcZBPjnJsKqlomYwaKcxaNKXe4FXGB9fi3si0fEt90pNBqTMjwOzzHj8jqu7PSz5A4tHfdNdJ+IN8IWI4S/YeqVXrdPtsM4Kpi/woSEYUd9Ma4ia/0fHjg4S6/Nb1cFFtx5OQejS6NIpOT3AcSkvOGfDQPHO3GhhZTufbmWeCiT4cOCgCZmlT6eDpl3R8eXWKIn6UGmBSfV1pqs7DFKSGMepV2HVsEtoButIlSfj2BP2mFJ6g1SstDsWCaw+jbtyN',
        user    => 'jenkins'
    }

    # this is the old jenkins key from the old server, it can go away eventually.
    ssh_authorized_key {'old_jenkins':
        ensure  => present,
        type    => 'ssh-rsa',
        key     => 'AAAAB3NzaC1yc2EAAAABIwAAAQEAuy/VESlo9iZAa9YQbEv9JGvvEsRKC3HxW2XivlDchGOxUNfrdaBGtFjMPe5rf6Qlv1hJ8bvHqZgCQIWYigRF45GXPJXGCaMWFoADG5+Mtr4SfoOWE8i6rVRphaKdIDV+UlhNQWlr4Cw/K4sgJB671qbSQjkn1H2uHiECMB1iUBtE8aOyDQm2bNzHh2sVyrDbUDm7zU354dIo84r3HhHVsK+3d0IhkiIhtWXc7IH4wL0pJ8B2Iv6FVLsQlY+pibGBPQzns25j83bPN01tj2JAxe6EqgsUyIJVu3Hb4UpFWkWquLQnOg0xbRHP/UnK5bQb/NI1ly/HKvt9xxQH8cEERQ==',
        user    => 'jenkins'
    }

    file { "${jenkins_home}/.ssh":
        ensure  => directory,
        owner   => jenkins,
        group   => jenkins,
        mode    => '0700',
    }

    file{"${jenkins_home}/.ssh/id_rsa":
        ensure => file,
        mode => 0600,
        owner => jenkins,
        group => jenkins,
        content => "${deploy_key}",
        require => File["${jenkins_home}/.ssh"],
    }

    file{"${jenkins_home}/.ssh/id_rsa.pub":
        mode => 0600,
        owner => jenkins,
        group => jenkins,
        content => "${deploy_key_pub}",
        require => File["${jenkins_home}/.ssh"],
    }

    file { ["${jenkins_home}/.m2", "${jenkins_home}/.gradle", "${jenkins_home}/plugins"]:
        ensure  => directory,
        owner   => jenkins,
        group   => jenkins,
        mode    => '0755',
        require => User['jenkins']
    }

    file{"${jenkins_home}/.m2/settings.xml":
        mode => 0600,
        owner => jenkins,
        group => jenkins,
        content => template("repose_jenkins/m2settings.xml.erb"),
        require => File["${jenkins_home}/.m2"]
    }
}