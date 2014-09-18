class conjur::example {
  include conjur::client
  class { conjur::host_identity:
    certificate => "-----BEGIN CERTIFICATE-----
MIIDCTCCAfGgAwIBAgIJAOuXj0Qr7TV9MA0GCSqGSIb3DQEBBQUAMCUxIzAhBgNV
BAMTGm1hc3Rlci5jb25qdXIudW0ucGwuZXUub3JnMB4XDTE0MDkwMTA4NDY0NFoX
DTI0MDgyOTA4NDY0NFowJTEjMCEGA1UEAxMabWFzdGVyLmNvbmp1ci51bS5wbC5l
dS5vcmcwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDIhcqj2K/eQEF4
lm7K5JHjRhodP3NHbA6jNL7yLnIi/v8rLB0ZDScnogWS4sA91Z/WcgvfGUCoSg/3
juYGxi/z9iam9zeMvgTDR4uMs9lmllmOmWjt9qqsPR4uCsPE2OXZDLgtx7Grzzwn
V61a5plHOLUfhr2GXbgqviQVAax356Eg5Iw+izs5mSxbkWlbkKp4/OyNYzjmhboE
7rggEKF5SlfcdhDYSMptQOxVUg9xDgGYONLAelqzlX1v/eUfPGlS5g2zPxq7/3VJ
XRT7gDwTFnEbH4RalzPQbG0uPuvqLRRi3h36QMsLXG/EIn5cOw23RlUj0BkCKXoH
Ftw9ekshAgMBAAGjPDA6MDgGA1UdEQQxMC+CCWxvY2FsaG9zdIIGY29uanVyghpt
YXN0ZXIuY29uanVyLnVtLnBsLmV1Lm9yZzANBgkqhkiG9w0BAQUFAAOCAQEAgJYK
F/eBOGuXnDx/dJj5nkCCfeh76zDtdQBD7HxNYgGbG8wt7UHQGArDmBIgV83+Mx2q
s2V5nmWe1A/59+H0edpZmWZPShMXC8K8B3KrPtkjS3BceOf+sUt9jCOJCv0yFAiZ
k2eYGu55Fi9zr3rK7NZSOQPYFnZ94rJgdUiI9Xa92dI1kiJCLFxDzczA5CojFaII
egijCvdBRErRNWfkatfVTpYYYMG0C0o1+3nonnZKqG28HBI66CKbb+c9IQQfLhqH
3zZRINW46TJZAv2mVpGIFCgYVmCk7A8VyjKDMi6HWE9mYUQzW9/PHLPpZbylZ/aD
MyE2lqgPMFa7yyJuOg==
-----END CERTIFICATE-----
",
    account => hatest,
    name => puppetest2,
    token => pw0jh51xwrn2v2tzfnc110x5s0xc5kv103ekxttvwzey3ygm8vek,
    appliance => 'https://master.conjur.um.pl.eu.org/api'
  }
}
