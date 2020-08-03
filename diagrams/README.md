# Workflows for Conjur Puppet Module

This directory includes sequence diagrams for three of the workflows
that are supported by the Conjur Puppet module:

- [Using Conjur Host Identity with Host Factory](../CONTRIBUTING.md#using-conjur-host-identity-with-host-factory)
- [Using Windows Registry / Windows Credential Manager Pre-Provisioning](../CONTRIBUTING.md#using-windows-registry--windows-credential-manager-pre-provisioning)
- [Using Host Identity with API Key Configured in Puppet Manifest](../CONTRIBUTING.md#using-host-identity-with-api-key-configured-in-puppet-manifest)

### Installing PlantUML and Rendering Diagrams

To render any of the sequence diagrams in this directory:

- Click on this link to download the PlantUML jar file: [Download PlantUML jar file](https://sourceforge.net/projects/plantuml/)
- Copy the downloaded `plantuml.jar` file:

  ```
  cp ~/Downloads/plantuml.jar .
  ```

- Run the following:

  ```
  java -jar ./plantuml.jar <sequence-diagram-source-file>
  ```
