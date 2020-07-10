# Usage:
#     install_puppet_agent.ps1 <MSI-download-file>

param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$msiFile
)

$usage = @"
Usage:
    install_puppet_agent.ps1 <MSI-download-file>

Example:
    install_puppet_agent.ps1 puppet-agent-5.5.8-x64.msi

Available Puppet Agent MSI files can be found here:
    https://downloads.puppetlabs.com/windows/puppet5/
    https://downloads.puppetlabs.com/windows/puppet6/
"@

# Check for required parameter
if (-not($msiFile)) {
    echo "ERROR: <MSI-download-file> not provided on command line"
    echo $usage
    exit 1
}

# Confirm that MSI file exists in \vagrant directory
$msiPath = "C:\vagrant\$msiFile"
echo "Checking to see if $msiPath exists" 
if (! ([System.IO.File]::Exists($msiPath))) {
    throw "File $msiFile does not exist. Please download from PuppetLabs."
}

# Install and start the Puppet agent
echo "Installing Puppet MSI file $msiFile"
Start-Process msiexec.exe -Wait -ArgumentList "/qn /quiet /norestart /L*v C:\vagrant\puppet_install_log.txt /i $msiPath PUPPET_MASTER_SERVER=puppet"

# Delete any existing entries for 'conjur' or 'puppet' in etc/hosts file
$etcHosts = "C:\Windows\System32\drivers\etc\hosts"
$names = @("conjur", "puppet")
foreach( $name in $names) {
    $entries = Get-Content $etcHosts | Select-String $name
    foreach( $entry in $entries) {
        echo "Deleting $etcHosts entry `"$entry`""
        (Get-Content $etcHosts) -replace $entry, ""| Set-Content $etcHosts
    }
}

# Add entries to .../etc/hosts file for 'conjur' and 'puppet' that point these
# domain names to `10.0.2.2`. This is a well-known, fixed IP address that is
# used by VirtualBox as a host IP address. (These 'conjur' and 'puppet'
# services are exposed on random host ports for any host IP address).
vboxHostIP = "10.0.2.2"
echo "Adding $etcHosts entry `"$vboxHostIP conjur`""
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "10.0.2.2 conjur"
echo "Adding $etcHosts entry `"$vboxHostIP puppet`""
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "10.0.2.2 puppet"
