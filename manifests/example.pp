class conjur::example {
  include conjur::client
  
  class { conjur::host_identity:
    certificate => file("conjur/example.pem"),
    account => hatest,
    name => hftest,
    key => '3bfqryknzbbmh1j3ecftgyac9w22677hw27z9yns3rcf29h3w2hvgn',
    appliance => 'https://master.conjur.um.pl.eu.org/api'
  }

  $planet = conjur_variable('planet')

  file { '/etc/hello.txt':
    content => "Hello $planet!\n"
  }

  conjurize_file { '/etc/hello.txt':
    map => {
      planet => "!var puppetdemo/planet"
    }
  }
}
