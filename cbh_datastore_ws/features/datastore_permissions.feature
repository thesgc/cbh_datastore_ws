Feature: Datastore Add Records Permissions

    Scenario: Project list

        Given testuser
        When I log in testuser
        Then I get a project list and I cannot see the project I do not have viewer rights on 
        Then I get a project list and I can see the projects I do have viewer rights on 


    Scenario: Data point classification GET

        Given testuser
        When I log in testuser
        Then I get classifications and I get 401 for the project I am not permitted to see



    Scenario: Data point classification POST
        Given testuser
        When I log in testuser
        Then I can post a classification to the project I have editor access to
        Then I cannot post a classification to the project I have read access to
        Then I cannot post a classification to the project I have no access to