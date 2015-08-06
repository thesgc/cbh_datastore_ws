Feature: Datastore Assay


    Scenario Outline: Project list includes my project if I have privileges
        Given a User
        and my user is member of a group 
        and a valid project exists proja
        and I automatically have editor permissions as creator
        and the project is configured for a simple assay and bioactivity 