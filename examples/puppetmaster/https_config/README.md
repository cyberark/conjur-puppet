To regenerate certificates, use [this](https://github.com/conjurdemos/dap-intro/tree/main/tools/simple-certificates)
tool:
```sh-session
# Generated leaf certificates are valid for 1 year, a value hardcoded into the script
# i.e. `-days 365`. To change the duration just change the hardcoded value. Similar changes
# can be made to the hardcoded durations of non-leaf certificates.
$ ./generate_certificates 1 conjur.cyberark.com
```

Copy the following:
- `certificates/ca-chain.cert.pem` -> `ca.crt`
- `certificates/nodes/conjur.cyberark.com/conjur.cyberark.com.cert.pem` -> `conjur.crt`
- `certificates/nodes/conjur.cyberark.com/conjur.cyberark.com.key.pem` -> `conjur.key`
