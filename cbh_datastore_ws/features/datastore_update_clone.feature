#Feature: Datastore Update Records#

#    Scenario: Given appropriate post data When I create a single record If I post the same data back no Object is created
#        Given a user
#        When I log in
#        Then appropriate post data When I create a single record If I post the same data back no Object is created#
#

#    Scenario: Post id back again
#        Given a user
#        When I log in
#        Then I post the original data back with the new id no record is created and there is an error#
#

#    Scenario: Post back referring to the previously created datapoint URI
#        Given a user
#        When I log in
#        Then I create a single recordIf I post the original data back with the new URI no record is created and there is an error#
#

#    Scenario: I can update DataPoints via a DataPointClassification
#        Given a user
#        When I log in
#        Then When I create a single record If I patchb the same data back, updating the l0 datapoint then only the l0 data point changes#
#

#    Scenario: I cannot update DataPoints via a DataPointClassification if conflicting
#        Given a user
#        When I log in
#        Then When I create a single record If I patch the same data back, updating one of the default datapoints then there is an error due to conflict#





#    Scenario: If I patch an l0 update which affects multiple datapoint classifications the index updates to reflect
#        Given a user
#        When I log in
#        If I patch an l0 update which affects multiple datapoint classifications the index updates to reflect