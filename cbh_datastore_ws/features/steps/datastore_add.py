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







# @given("a valid project myproj where i have editor permissions as creator")
# def step(context):
#     Project.objects.create(   ProjectType.objects.filter()[0]
#     Then I post to myproj and the response is valid JSON















