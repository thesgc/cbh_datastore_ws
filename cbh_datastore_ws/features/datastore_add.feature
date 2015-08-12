Feature: Datastore Add Records

    Scenario: Project list

        Given a user
        When I log in
        Then I get a project list Given I am an admin JSON data is available The first form from the test fixtures has the given URI

    Scenario: Data point classification GET

        Given a user
        When I log in
        Then Given I have loaded one classification record into the database  Given I am an adminWhen I call get classifier I see no records


    Scenario: Data point classification POST
        Given a user
        When I log in
        Then I post and the response is valid JSON



#     Scenario: I can retrive only data classifications from one form


#    Scenario: I am not allowed to patch update DataPoints via a DataPointClassification


#    Scenario: I am allowed to patch archive a DataPointClassification (relevant data classifications chosen via GET request)


#    Scenario: Archived data is somehow not counted in the unique key


#    Scenario: I am allowed to patch a DataPoint


#    Scenario: DataPoints are only marked as archived via their parent classifications(to avoid confusion)


#    Scenario: I can retrieve data points in a tree format from a certain node outwards (or do on frontend)


#    Scenario I am allowed to see DataPointClassifications in projects I am a viewer for


#    Scenario I am not allowed to update DataPointClassifications in projects I am a viewer for

#    Scenario I am not allowed to see any DataPointClassifications in projects I have no permissions on



#    Scenario I am allowed to view all of the available Assay forms without permissions


