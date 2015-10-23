Feature: Upload Records

    Scenario: Create Attachment Record
        Given testuser
        When I log in testuser
        Given I create custom field configs based on the data given
        Given I create a project and add each sheet in turn

