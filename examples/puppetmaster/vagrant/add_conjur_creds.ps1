# Add a Conjur API key for host 'node01' to the Windows Registry
# Usage:
#     add_conjur_creds.ps1 <api-key-for-host-node01> <conjur-host-port>

param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$apiKey,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [String]$conjurHostPort
)

$usage = @"
Usage:
    add_conjur_creds.ps1 <conjur-api-key-for-host-node01> <conjur-host-port>

To generate an API key for host 'node01' to pass to this shell script,
run the command:
    docker exec <conjur-cli-container-id> conjur host rotate_api_key -h node01
"@

# Check for required parameters
if (-not($apiKey)) {
    echo "ERROR: <conjur-api-key-for-host-node01> not provided on command line"
    echo $usage
    exit 1
}
if (-not($conjurHostPort)) {
    echo "ERROR: <conjur-host-port> not provided on command line"
    echo $usage
    exit 1
}

"Add Conjur credentials to the Windows Credential Manager..."
Invoke-Expression -Command "cmdkey /generic:https://conjur-https:$conjurHostPort /user:host/node01 /pass:$apiKey"
