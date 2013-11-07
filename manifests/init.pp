class mod_cluster {

  $mc_version   = "1.2.0.Final"
  $mc_download  = "http://downloads.jboss.org/mod_cluster/${mc_version}/mod_cluster-${mc_version}-linux2-x64-so.tar.gz"
  $apache_modules = "/usr/lib/apache2/modules"

  package { "apache2":
    ensure => present
  }

  exec { download_mc:
    command   => "wget -O /tmp/mod_cluster.tar.gz ${mc_download}",
    path      => $path,
    creates   => "/tmp/mod_cluster.tar.gz",
    unless    => "ls ${apache_modules} | grep mod_proxy_cluster.so",
    require   => Package[apache2]
  }

  exec { unpack_mc:
    command   => "tar -C ${apache_modules} -zxf /tmp/mod_cluster.tar.gz",
    path      => $path,
    creates   => [
        "${apache_modules}/mod_advertise.so",
        "${apache_modules}/mod_manager.so",
        "${apache_modules}/mod_proxy_cluster.so",
        "${apache_modules}/mod_slotmem.so",
      ],
    require   => Exec[download_mc]
  }

  file { "/etc/apache2/logs":
    ensure    => link,
    target    => "/var/log/apache2",
    require   => Package['apache2']
  }

  file { "proxy_cluster.load":
    ensure    => file,
    path      => "/etc/apache2/mods-available/proxy_cluster.load",
    content   => template('mod_cluster/proxy_cluster.load'),
    require   => File['/etc/apache2/logs'],
    notify    => Service['apache2'],
  }

  file { "proxy_cluster.conf":
    ensure    => file,
    path      => "/etc/apache2/mods-available/proxy_cluster.conf",
    content   => template('mod_cluster/proxy_cluster.conf.erb'),
    require   => File["proxy_cluster.load"],
    notify    => Service['apache2'],
  }

  define enable_mods {
    exec { "Enable $name":
      command   => "a2enmod $name",
      path      => $path,
      creates   => "/etc/apache2/mods-enabled/${$name}.load",
      require   => File["proxy_cluster.conf"],
      notify    => Service['apache2'],
    }
  } 

  $cluster_modules = ['proxy', 'proxy_http', 'proxy_ajp', 'proxy_cluster']

  enable_mods { $cluster_modules: }

  service { "apache2":
    enable    => true,
    ensure    => running,
    require   => Package[apache2]
  }

  exec { "a2dissite default":
    path      => $path,
    require   => Package[apache2],
    notify    => Service[apache2],
  }

  file { "/etc/apache2/sites-available/mod_cluster":
    ensure    => file,
    path      => "/etc/apache2/sites-available/mod_cluster",
    content   => template('mod_cluster/mod_cluster'),
    require   => Exec['Enable proxy_cluster'],
  }

  exec { "a2ensite mod_cluster":
    path      => $path,
    require   => File['/etc/apache2/sites-available/mod_cluster'],
    notify    => Service['apache2'],
  }

}

