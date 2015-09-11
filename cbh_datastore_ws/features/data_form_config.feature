Feature: Data form configs allow configuration of a specific possible route that a user can take through the system

    Scenario: Keys to allow different possible routes to be presented to the user 
        Given testuser
        When I log in testuser
        Then The data form configs in the enabled forms list of a project have keys to allow routes through the system to be presented to the user