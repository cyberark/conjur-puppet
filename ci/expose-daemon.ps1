$ErrorActionPreference = 'Stop';

if (!(Test-Path $env:USERPROFILE\.docker)) {
  mkdir $env:USERPROFILE\.docker
}

$ipAddresses = ((Get-NetIPAddress -AddressFamily IPv4).IPAddress) -Join ','

function ensureDirs($dirs) {
  foreach ($dir in $dirs) {
    if (!(Test-Path $dir)) {
      mkdir $dir
    }
  }
}

# https://docs.docker.com/engine/security/https/
# Thanks to @artisticcheese! https://artisticcheese.wordpress.com/2017/06/10/using-pure-powershell-to-generate-tls-certificates-for-docker-daemon-running-on-windows/
function createCA($serverCertsPath) {
  Write-Host "`n=== Generating CA"
  $parms = @{
    type = "Custom" ;
    KeyExportPolicy = "Exportable";
    Subject = "CN=Docker TLS Root";
    CertStoreLocation = "Cert:\LocalMachine\My";
    HashAlgorithm = "sha256";
    KeyLength = 4096;
    KeyUsage = @("CertSign", "CRLSign");
    TextExtension = @("2.5.29.19 ={critical} {text}ca=1")
  }
  $rootCert = New-SelfSignedCertificate @parms

  Write-Host "`n=== Generating CA public key"
  $parms = @{
    Path = "$serverCertsPath\ca.pem";
    Value = "-----BEGIN CERTIFICATE-----`n" `
          + [System.Convert]::ToBase64String($rootCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) `
          + "`n-----END CERTIFICATE-----";
    Encoding = "ASCII";
  }
  Set-Content @parms
  return $rootCert
}

# https://docs.docker.com/engine/security/https/
function createCerts($rootCert, $serverCertsPath, $serverName, $ipAddresses, $clientCertsPath) {
  Write-Host "`n=== Generating Server certificate"
  $parms = @{
    CertStoreLocation = "Cert:\LocalMachine\My";
    Signer = $rootCert;
    Subject = "CN=serverCert";
    KeyExportPolicy = "Exportable";
    Provider = "Microsoft Enhanced Cryptographic Provider v1.0";
    Type = "SSLServerAuthentication";
    HashAlgorithm = "sha256";
    TextExtension = @("2.5.29.37= {text}1.3.6.1.5.5.7.3.1", "2.5.29.17={text}DNS=$serverName&DNS=localhost&IPAddress=$($ipAddresses.Split(',') -Join '&IPAddress=')");
    KeyLength = 4096;
  }
  $serverCert = New-SelfSignedCertificate @parms

  $parms = @{
    Path = "$serverCertsPath\server-cert.pem";
    Value = "-----BEGIN CERTIFICATE-----`n" `
          + [System.Convert]::ToBase64String($serverCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) `
          + "`n-----END CERTIFICATE-----";
    Encoding = "Ascii"
  }
  Set-Content @parms

  Write-Host "`n=== Generating Server private key"
  $privateKeyFromCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($serverCert)
  $parms = @{
    Path = "$serverCertsPath\server-key.pem";
    Value = ("-----BEGIN PRIVATE KEY-----`n" `
          + [System.Convert]::ToBase64String($privateKeyFromCert.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob), [System.Base64FormattingOptions]::InsertLineBreaks) `
          + "`n-----END PRIVATE KEY-----");
    Encoding = "Ascii";
  }
  Set-Content @parms

  Write-Host "`n=== Generating Client certificate"
  $parms = @{
    CertStoreLocation = "Cert:\LocalMachine\My";
    Subject = "CN=clientCert";
    Signer = $rootCert ;
    KeyExportPolicy = "Exportable";
    Provider = "Microsoft Enhanced Cryptographic Provider v1.0";
    TextExtension = @("2.5.29.37= {text}1.3.6.1.5.5.7.3.2") ;
    HashAlgorithm = "sha256";
    KeyLength = 4096;
  }
  $clientCert = New-SelfSignedCertificate  @parms

  $parms = @{
    Path = "$clientCertsPath\cert.pem" ;
    Value = ("-----BEGIN CERTIFICATE-----`n" + [System.Convert]::ToBase64String($clientCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END CERTIFICATE-----");
    Encoding = "Ascii";
  }
  Set-Content @parms

  Write-Host "`n=== Generating Client key"
  $clientprivateKeyFromCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($clientCert)
  $parms = @{
    Path = "$clientCertsPath\key.pem";
    Value = ("-----BEGIN PRIVATE KEY-----`n" `
          + [System.Convert]::ToBase64String($clientprivateKeyFromCert.Key.Export([System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob), [System.Base64FormattingOptions]::InsertLineBreaks) `
          + "`n-----END PRIVATE KEY-----");
    Encoding = "Ascii";
  }
  Set-Content @parms

  copy $serverCertsPath\ca.pem $clientCertsPath\ca.pem
}

function updateConfig($daemonJson, $serverCertsPath) {
  $config = @{}
  if (Test-Path $daemonJson) {
    $config = (Get-Content $daemonJson) -join "`n" | ConvertFrom-Json
  }

  $config = $config | Add-Member(@{ `
    hosts = @("tcp://0.0.0.0:2376", "npipe://"); `
    tlsverify = $true; `
    tlscacert = "$serverCertsPath\ca.pem"; `
    tlscert = "$serverCertsPath\server-cert.pem"; `
    tlskey = "$serverCertsPath\server-key.pem" `
    }) -Force -PassThru

  Write-Host "`n=== Creating / Updating $daemonJson"
  $config | ConvertTo-Json | Set-Content $daemonJson -Encoding Ascii
}

$dockerData = "$env:ProgramData\docker"
$userPath = "$env:USERPROFILE\.docker"

Write-Host "Updating and Restarting Docker"

Stop-Service docker
Remove-Item -Recurse -Force $dockerData
Invoke-WebRequest https://get.docker.com/builds/Windows/x86_64/docker-1.13.1.zip -UseBasicParsing -OutFile docker.zip
Expand-Archive docker.zip -DestinationPath $Env:ProgramFiles -Force
Remove-Item -Force docker.zip
Start-Service docker

ensureDirs @("$dockerData\certs.d", "$dockerData\config", "$userPath")

$serverCertsPath = "$dockerData\certs.d"
$clientCertsPath = "$userPath"
$rootCert = createCA "$dockerData\certs.d"

createCerts $rootCert $serverCertsPath $serverName $ipAddresses $clientCertsPath
updateConfig "$dockerData\config\daemon.json" $serverCertsPath $enableLCOW $experimental

Write-Host "Restarting Docker"
Restart-Service docker

Write-Host "Opening Docker TLS port"
& netsh advfirewall firewall add rule name="Docker TLS" dir=in action=allow protocol=TCP localport=2376
