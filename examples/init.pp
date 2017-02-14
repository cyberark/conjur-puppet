# The baseline for module testing used by Puppet Labs is that each manifest
# should have a corresponding test manifest that declares that class or defined
# type.
#
# Tests are then run by using puppet apply --noop (to check for compilation
# errors and view a log of events) or by fully applying the test in a virtual
# environment (to compare the resulting system state to the desired state).
#
# Learn more about module testing here:
# https://docs.puppet.com/guides/tests_smoke.html
#

class { conjur:
  appliance_url => "https://localhost:8443/api",
  authn_login => "host/pphost",
  host_factory_token => "21rzdwb2n4m6wb16tg3q03m572ac2gb3ktkgtpzw8146t77s2z2vbr7",
  # authn_api_key => "dfh4c01pyhxej345zptd28vt8nr35m3dwf2m1g03m9vhpva1mkg4zy",
  ssl_certificate => @(EOT)
    -----BEGIN CERTIFICATE-----
    MIID7DCCAtSgAwIBAgIJAJyeKBfK89SvMA0GCSqGSIb3DQEBCwUAMD0xETAPBgNV
    BAoTCGN1Y3VtYmVyMRIwEAYDVQQLEwlDb25qdXIgQ0ExFDASBgNVBAMTC2N1a2Ut
    bWFzdGVyMB4XDTE3MDEyMDE4Mjc1OVoXDTI3MDExODE4Mjc1OVowPTERMA8GA1UE
    ChMIY3VjdW1iZXIxEjAQBgNVBAsTCUNvbmp1ciBDQTEUMBIGA1UEAxMLY3VrZS1t
    YXN0ZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCxeMrSM8J5j1U9
    O48HmrK6rm4VXKaZiwKpxNsVWlaXNlCLP4brjUXGa0seYUaYWjPegTsi2aQCYNSg
    +o3DxR9RtwYgkKXE3Ity5Dq7EpijzPNm5PmNsSZWDcd+UOLQrkAfcgWrGHunKhjT
    vecRHbbiuCyv10zo9q/YfgMn2CjyVFF5VzI9YSzuYMCpHhr9+51wOpnzyAHf3nvg
    /XZ3R/CyBkb+ZFBKY6V4KsIYMFB02LlnVY6QqaVG5onV0UDC2+TYxKz9UmESKEk0
    ozstYoI4MoCzl0QIPl3xpPrh1uNrcZzBMe3lnkw2vX8WtX3oxx6JJU7uzRUTjDxI
    v7Ne2mdZAgMBAAGjge4wgeswgY0GA1UdEQSBhTCBgoILY3VrZS1tYXN0ZXKCEmN1
    a2UtbWFzdGVyLmRvY2tlcoITY3VrZS1zdGFuZGJ5LmRvY2tlcoIMY3VrZS1zdGFu
    ZGJ5ghdjdWtlLW1hc3Rlci1zZWVkLmRvY2tlcoIQY3VrZS1tYXN0ZXItc2VlZIIG
    Y29uanVygglsb2NhbGhvc3QwHQYDVR0OBBYEFEHaLT4U58HR4DcPZx/2mQ/DIzNb
    MB8GA1UdIwQYMBaAFEHaLT4U58HR4DcPZx/2mQ/DIzNbMAwGA1UdEwQFMAMBAf8w
    CwYDVR0PBAQDAgHmMA0GCSqGSIb3DQEBCwUAA4IBAQBUVmyRJxj9rK9iqoJe9a3r
    7ju86DFlFNnG8fFhKlOdW5LlhsS2wmypnOERF8bxnFZig0M7l99uSLYYI0CIyRnZ
    1kdWEOc3C/90LxezmvFUo1o/znSan442gbJsucpDIo3cbkwjb46dQOgm64gPCA8P
    lNyIOYZTXV2Gao1or0kKMUE99yrFsmb4PG6/wOiCLg55ZE5uDnqKzZgL4sgjASC2
    4srl3GzbEbDwwfbf5SQQ38tJTmI80Zu4jlBxVL40nzMdMrdxm26nsORBqrfIXd2E
    lypQMJ+5VFop4gkUPg4vNCDKol29+eKLv20DGj1JWH6vwy52UpL7l8E8h1Vnoqn6
    -----END CERTIFICATE-----
    |-EOT
}

file { '/tmp/db-password':
  content => conjur::secret('inventory/db-password'),
  ensure => file,
  show_diff => false  # don't log file content!
}
