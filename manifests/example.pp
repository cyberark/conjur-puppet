class conjur::example {
  class { conjur:
    conjur_certificate => file("conjur/example.pem"),
    conjur_account => hatest,
    conjur_url => 'https://master.conjur.um.pl.eu.org/api',

    host_id => hftest,
    host_key => '3bfqryknzbbmh1j3ecftgyac9w22677hw27z9yns3rcf29h3w2hvgn'
  }

  $planet = conjur_variable('planet')

  file { '/etc/hello.txt':
    content => "Hello $planet!\n"
  }

  conjurize_file { '/etc/hello.txt':
    variable_map => {
      planet => "!var puppetdemo/planet"
    }
  }
}
