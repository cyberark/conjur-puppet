# Add Conjur connection settings Windows registry
# Usage:
#     add_conjur_registry.ps1 <conjur-host-port>

param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$conjurHostPort
)


$usage = @"
Usage:
    add_conjur_registry.ps1 <conjur-host-port>
"@

if (-not($conjurHostPort)) {
    echo "ERROR: <conjur-host-port> not provided on command line"
    echo $usage
    exit 1
}

reg ADD HKLM\Software\CyberArk\Conjur /f /v ApplianceUrl /t REG_SZ /d https://conjur-https:$conjurHostPort
reg ADD HKLM\Software\CyberArk\Conjur /f /v Version /t REG_DWORD /d 5
reg ADD HKLM\Software\CyberArk\Conjur /f /v Account /t REG_SZ /d cucumber

reg ADD HKLM\Software\CyberArk\Conjur /f /v CertFile /t REG_SZ /d "/vagrant/.tmp/conjur_ca.pem"
# $ssl_certificate = Get-Content -Raw -Path /vagrant/.tmp/conjur_ca.pem
# reg ADD HKLM\Software\CyberArk\Conjur /f /v SslCertificate /t REG_SZ /d "$ssl_certificate"
