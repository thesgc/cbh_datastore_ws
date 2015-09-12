Feature: Data form configs allow configuration of a specific possible route that a user can take through the system

    Scenario: Keys to allow different possible routes to be presented to the user 
        Given testuser
        When I log in testuser
        Then The data_form_configs in the project output have permitted children and there is a single root object