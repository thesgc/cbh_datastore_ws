# -*- coding: utf-8 -*-
"""steps/browser_steps.py -- step implementation for our browser feature demonstration.
"""
from behave import given, when, then
import json
from cbh_core_model.models import Project, CustomFieldConfig, PinnedCustomField, ProjectType
from cbh_datastore_model.models import DataPoint, DataPointClassification
from django.db import IntegrityError

@when('I log in')
def step(context):
    context.test_case.assertTrue(context.api_client.client.login(username="foo", password="bar"))
 
 

@given("tester")
def step(context):
    print("test")

@when("tester2")
def step(context):
    print("test")
    
@then("I get a project list Given I am an admin JSON data is available The first form from the test fixtures has the given URI")
def step(context):
    """"""
    result = context.api_client.get("/dev/datastore/cbh_projects_with_forms")

    data = json.loads(result.content)
    context.test_case.assertEqual(data["objects"][0]["enabled_forms"][0]["resource_uri"], u"/dev/datastore/cbh_data_form_config/4")


@then("Given I have loaded one classification record into the database  Given I am an adminWhen I call get classifier I see no records")
def step(context):
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 0)

@then("I post and the response is valid JSON")
def step(context):
    print("mytest")
    post_data = {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
                
                "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] }
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
format="json", 
data= post_data)
    context.test_case.assertHttpCreated(created)
    data = json.loads(created.content)
    context.test_case.assertEquals(data["l0_permitted_projects"], ["/dev/datastore/cbh_projects_with_forms/8"])


@then("appropriate post data When I create a single record If I post the same data back no Object is created")
def step(context):
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 0)

    post_data = {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
                "l0": {"custom_field_config":{"pk":577},"project_data":{"some_test":"project_data"}},
                "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] }
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
format="json", 
data= post_data)

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)

    data = json.loads(created.content)

    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
format="json", 
data= data)

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)



@then("I post the original data back with the new id no record is created and there is an error")
def test_try_to_post_duplicate_using_id(context):
    """
    """
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 0)

    post_data = {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
                "l0": {"custom_field_config":{"pk":577},"project_data":{"some_test":"project_data"}},
                "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] }
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
format="json", 
data= post_data)

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)
    data = json.loads(created.content)

    post_data["l0"]["id"] = data["l0"]["id"]
    try:

        created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
    format="json", 
    data= post_data)
    except IntegrityError:
        pass
    
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)


@then("Given appropriate post data Given I am an adminWhen I create a single recordIf I post the original data back with the new URI no record is created and there is an error")
def test_try_to_post_duplicate_using_id(context):
    
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 0)

    post_data = {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
                "l0": {"custom_field_config":{"pk":577},"project_data":{"some_test":"project_data"}},
                "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] }
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
format="json", 
data= post_data)

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)
    data = json.loads(created.content)

    #To post resource uris we just pass a string
    post_data["l0"] = data["l0"]["resource_uri"]
    try:
        created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
    format="json", 
    data= post_data)
    except IntegrityError:
        pass
    
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)