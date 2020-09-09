FROM mcr.microsoft.com/windows/servercore:1607

RUN powershell mkdir "c:\tmp"

RUN powershell \
  wget https://downloads.puppetlabs.com/windows/puppet6/puppet-agent-x64-latest.msi \
    -outfile puppet6.msi

RUN powershell Start-Process msiexec.exe \
   -Wait \
   -ArgumentList \
    '/qn /quiet /norestart /L*v C:\puppet_install_log.txt /i C:\puppet6.msi PUPPET_AGENT_STARTUP_MODE=Manual'
