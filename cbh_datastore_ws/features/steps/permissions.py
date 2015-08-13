from behave import given, when, then
import json
from cbh_core_model.models import Project, CustomFieldConfig, PinnedCustomField, ProjectType
from cbh_datastore_model.models import DataPoint, DataPointClassification
from django.db import IntegrityError

@given("testuser")
def step(context):
    pass

@when("I log in testuser")
def step(context):
    context.user.login(username="testuser", password="testuser")
    


@then("I get a project list and I cannot see the project I do not have viewer rights on ")
def step(context):
    """"""
    result = context.api_client.get("/dev/datastore/cbh_projects_with_forms")

    has_no_viewer_project = result.content.index("/dev/datastore/cbh_projects_with_forms/4/")
    context.test_case.assertEquals(has_no_viewer_project, -1)



@then("Then I get a project list and I can see the projects I do have viewer rights on")
def step(context):
    """"""
    result = context.api_client.get("/dev/datastore/cbh_projects_with_forms")

    has_viewer_project = result.content.index("/dev/datastore/cbh_projects_with_forms/5/")
    context.test_case.assertGreater(has_viewer_project, -1)

    has_editor_project = result.content.index("/dev/datastore/cbh_projects_with_forms/3/")
    context.test_case.assertGreater(has_editor_project, -1)





# @then("Given I have loaded one classification record into the database  Given I am an adminWhen I call get classifier I see no records")
# def step(context):
#     classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
#     classif = json.loads(classif.content)
#     context.test_case.assertEquals(classif["meta"]["total_count"], 0)

# @then("I post and the response is valid JSON")
# def step(context):
#     print("mytest")
#     post_data = {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
                
#                 "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] }
#     created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
# format="json", 
# data= post_data)
#     context.test_case.assertHttpCreated(created)
#     data = json.loads(created.content)
#     context.test_case.assertEquals(data["l0_permitted_projects"], ["/dev/datastore/cbh_projects_with_forms/8"])



