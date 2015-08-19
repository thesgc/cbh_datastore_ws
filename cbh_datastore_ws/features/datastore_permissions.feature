Feature: Datastore Add Records Permissions

    Scenario: Project list

        Given testuser
        When I log in testuser
        Then I get a project list and I cannot see the project I do not have viewer rights on
        Then I get a project list and I can see the projects I do have viewer rights on 


    Scenario: Data point classification GET

        Given testuser
        When I log in testuser
        Given a datapointclassification is linked to a project I do not have access to and another is in readonly
        Then I get classifications and I see only 1 record from my readonly project
        Then I reindex Elasticsearch
        Then I request all data from the elasticsearch index and see only 1 record from my readonly project



    Scenario: Data point classification POST
        Given testuser
        When I log in testuser
        Then I POST a new classification to my editor project and get 201
        Then I POST a new classification to my viewer project and get 401
        Then I POST a new classification to the project I have no permissions on and get 401
        Then I POST a new classification without linked project and get 400






