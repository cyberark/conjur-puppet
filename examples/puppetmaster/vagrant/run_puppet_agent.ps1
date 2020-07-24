# Usage:
#     run_puppet_agent.ps1 <puppet-svr-host-port>

param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$puppetSvrHostPort
)

# Break on all errors
$ErrorActionPreference = "Stop"

$usage = @"
Usage:
    run_puppet_agent.ps1 <puppet-svr-host-port>

Example:
    run_puppet_agent.ps1 34567
"@

# Check for required parameter
if (-not($puppetSvrHostPort)) {
    echo "ERROR: <puppet-svr-host-port> not provided on command line"
    echo $usage
    exit 1
}

$vagrant_cert_dir = "/vagrant/.tmp"
$puppet_cert_dir = "/ProgramData/PuppetLabs/puppet/etc/ssl/certs"

"Recreating Puppet SSL directory..."
rm -r /ProgramData/PuppetLabs/puppet/etc/ssl
New-Item "$puppet_cert_dir" `
  -ItemType Directory -ErrorAction SilentlyContinue

"Copying Puppet CA cert files from $vagrant_cert_dir to Puppet certs dir..."
Copy-Item "$vagrant_cert_dir/puppet_ca_crt.pem" -Destination "$puppet_cert_dir/ca.pem"
Copy-Item "$vagrant_cert_dir/puppet_ca_crl.pem"  -Destination "$puppet_cert_dir/crl.pem"

"Running Puppet Agent..."
puppet agent --onetime `
             --no-daemonize `
             --no-usecacheonfailure `
             --no-splay `
             --debug `
             --masterport "$puppetSvrHostPort"
