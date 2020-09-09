# Workflows for Conjur Puppet Module

This directory includes sequence diagrams for the workflows that are supported
by the Conjur Puppet module. To see them, go to our
[CONTRIBUTING.md](../CONTRIBUTING.md#sequence-diagrams) document.

## Generating the diagram images

### Online Diagram Rendering

- Visit [PlantUML](http://www.plantuml.com/plantuml/uml)
- Enter the diagram text
- Click `Submit` to generate a new diagram image

### Local Diagram Rendering

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
