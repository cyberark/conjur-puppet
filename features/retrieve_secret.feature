Feature: Retrieving a secret value from Conjur

Background:
  Given a puppet integration environment in AWS with agents:
    | name                    | platform | ami                   |
    | agent-redhat.puppet     | RedHat   | ami-0de53d8956e8dcf80 |
    | agent-win-2008r2.puppet | Windows  | ami-0ed62a915794ca035 |
    | agent-win-2019.puppet   | Windows  | ami-0204606704df03e7e |
    | agent-win-core.puppet   | Windows  | ami-0b0155d73993a98fb | 

  And I load the integration Conjur policy
  And I install the current puppet module

Scenario Outline: Retrieve a secret using the Host Factory identity
  Given I clear the Conjur identity for '<agent>'
  And I trigger the puppet agent on '<agent>'
  When I retrieve the test page for '<agent>'
  Then the result contains the value for 'secrets/a'
  Then the result does not contain the value for 'secrets/b'

  Examples:
  | agent                   |
  | agent-redhat.puppet     |
  | agent-win-2008r2.puppet |
  | agent-win-2019.puppet   |
  | agent-win-core.puppet   |

Scenario Outline: Retrieve a secret using pre-established identity
  Given I clear the Conjur identity for '<agent>'
  And I add configure '<agent>' with the Conjur identity for 'my-host'
  And I trigger the puppet agent on '<agent>'

  When I retrieve the test page for '<agent>'
  Then the result contains the value for 'secrets/b'
  Then the result does not contain the value for 'secrets/a'


  Examples:
  | agent                   |
  | agent-redhat.puppet     |
  | agent-win-2008r2.puppet |
  | agent-win-2019.puppet   |
  | agent-win-core.puppet   |
