Feature: Retrieving a secret value from Conjur

Background:
  Given a puppet integration environment in AWS with agents:
    | name                    | platform | ami                   |
    | agent-redhat.puppet     | RedHat   | ami-0de53d8956e8dcf80 |
    | agent-win-2008r2.puppet | Windows  | ami-062d3fb9f5d18af75 |
    | agent-win-2019.puppet   | Windows  | ami-09ef280df1a6a5330 |
    | agent-win-core.puppet   | Windows  | ami-04f46af0096c1d8b9 | 

  And I load the integration Conjur policy
  And I install the current puppet module

Scenario Outline: Retrieve a secret using the Host Factory identity
  Given I clear the Conjur identity for '<agent>'
  When I trigger the puppet agent on '<agent>'
  Then the test page for '<agent>' contains the value for 'secrets/a'
  And the test page for '<agent>' does not contain the value for 'secrets/b'

  Examples:
  | agent                   |
  | agent-redhat.puppet     |
  | agent-win-2008r2.puppet |
  | agent-win-2019.puppet   |
  | agent-win-core.puppet   |

Scenario Outline: Retrieve a secret using pre-established identity
  Given I clear the Conjur identity for '<agent>'
  When I add configure '<agent>' with the Conjur identity for 'my-host'
  And I trigger the puppet agent on '<agent>'

  Then the test page for '<agent>' contains the value for 'secrets/b'
  And the test page for '<agent>' does not contain the value for 'secrets/a'


  Examples:
  | agent                   |
  | agent-redhat.puppet     |
  | agent-win-2008r2.puppet |
  | agent-win-2019.puppet   |
  | agent-win-core.puppet   |
