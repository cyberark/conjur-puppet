require_relative './base_agent'

module Agents
  class Windows < BaseAgent
    def initialize(agent, ndx,
      appliance_url:,
      appliance_host:,
      appliance_ca_cert:
    )
      super(agent, ndx)

      @appliance_url = appliance_url
      @appliance_host = appliance_host
      @appliance_ca_cert = appliance_ca_cert
    end

    def run
      powershell_execute(<<~EOS
          $psexecPath = "C:\\PSTools\\PsExec.exe"
          if (!(Test-Path $psexecPath)) {
            Invoke-WebRequest -Uri "https://download.sysinternals.com/files/PSTools.zip" -OutFile "C:\\PSTools.zip"

            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory("C:\\PSTools.zip", "C:\\PSTools")
          }

          echo "Stopping puppet service"
          Stop-Service puppet

          echo "Running puppet agent"
          $count = 0
          do{
              C:\\PSTools\\PsExec.exe -nobanner -accepteula -s "C:\\Program Files\\Puppet Labs\\Puppet\\bin\\puppet.bat" agent --test 2>&1 | %{ "$_" }
              $success = (($LastExitCode -ne 1))

              if(($LastExitCode -eq 1)) {
                echo 'Waiting for Puppet agent...'
                Start-sleep -Seconds 10
              }

              $count++
          }until($count -eq 10 -or $success)

          echo "Starting puppet service"
          Start-Service puppet

          invoke-command -scriptblock {iisreset}
          Start-sleep -Seconds 10
        EOS
        )
    end

    def clear_identity
      powershell_execute(<<~EOS
          $psexecPath = "C:\\PSTools\\PsExec.exe"
          if (!(Test-Path $psexecPath)) {
            Invoke-WebRequest -Uri "https://download.sysinternals.com/files/PSTools.zip" -OutFile "C:\\PSTools.zip"

            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory("C:\\PSTools.zip", "C:\\PSTools")
          }

          Reg delete HKLM\\Software\\CyberArk\\Conjur /f
          C:\\PSTools\\PsExec.exe -nobanner  -accepteula -s cmdkey /delete:#{@appliance_host} 2>&1 | %{ "$_" }
          EOS
        )
    end

    def configure_identity(host_id:, api_key:)
      powershell_execute(<<~EOS
        $psexecPath = "C:\\PSTools\\PsExec.exe"
        if (!(Test-Path $psexecPath)) {
          Invoke-WebRequest -Uri "https://download.sysinternals.com/files/PSTools.zip" -OutFile "C:\\PSTools.zip"

          Add-Type -AssemblyName System.IO.Compression.FileSystem
          [System.IO.Compression.ZipFile]::ExtractToDirectory("C:\\PSTools.zip", "C:\\PSTools")
        }

        reg ADD HKLM\\Software\\CyberArk\\Conjur /f
        reg ADD HKLM\\Software\\CyberArk\\Conjur /f /v ApplianceUrl /t REG_SZ /d #{@appliance_url}
        reg ADD HKLM\\Software\\CyberArk\\Conjur /f /v Version /t REG_DWORD /d 5
        reg ADD HKLM\\Software\\CyberArk\\Conjur /f /v Account /t REG_SZ /d puppet
        reg ADD HKLM\\Software\\CyberArk\\Conjur /f /v SslCertificate /t REG_SZ /d "#{@appliance_ca_cert}"

        C:\\PSTools\\PsExec.exe -nobanner  -accepteula -s cmdkey /generic:#{@appliance_host} /user:#{host_id} /pass:#{api_key} 2>&1 | %{ "$_" }
      EOS
      )
    end

    private

    def powershell_execute(command)
      conn = WinRM::Connection.new(windows_agent_connect_opts)
      conn.shell(:powershell) do |shell|
        shell.run(command) do |stdout, stderr|
          STDOUT.print stdout
          STDERR.print stderr
        end
      end
    end

    def windows_agent_connect_opts
      { 
        endpoint: "http://#{host}:5985/wsman",
        user: 'administrator',
        password: password
      }
    end

    def password
      private_key = OpenSSL::PKey::RSA.new(ssh_private_key_pem)
      private_key.private_decrypt(Base64.decode64(password_data))
    end

    def password_data
      Util::Terraform.output('puppet_agent_windows_password')[index]
    end
  end
end
