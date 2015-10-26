from behave import given, when, then
import json
from cbh_core_model.models import Project, CustomFieldConfig, PinnedCustomField, ProjectType
from cbh_datastore_model.models import DataPoint, DataPointClassification, DataPointClassificationPermission
from django.db import IntegrityError
from django.contrib.auth.models import User

@given("testuser")
def step(context):
    pass


@when("I log in testuser")
def logintestuser(context):
    context.api_client.client.login(username="testuser", password="testuser")


@then("I get a project list and I cannot see the project I do not have viewer rights on")
def step(context):
    """"""
    result = context.api_client.get(
        "/dev/datastore/cbh_projects_with_forms", format="json")
    context.test_case.assertValidJSON(result.content)
    try:
        has_no_viewer_project = result.content.index(
            '"/dev/datastore/cbh_projects_with_forms/4"')
        context.test_case.assertTrue(False)

    except ValueError:
        # Exception should throw
        context.test_case.assertTrue(True)


@then("I add permissions for the root datapointclassification")
def step(context):
    DataPointClassificationPermission.objects.create(
        project_id=3, data_point_classification=context.l0_dpc)


@then("I GET data point classifications with nesting and see the new l1 datapoint as a child")
def step(context):
    '''Here we are checking that the children data is available via the nested call'''
    result = context.api_client.get(
        "/dev/datastore/cbh_datapoint_classifications_nested?full=true", format="json")
    context.test_case.assertValidJSON(result.content)
    data = json.loads(result.content)
    found_new_object_as_child = False
    print (data.keys())
    for obj in data["objects"]:
        for child in obj["children"]:
            if child["l1"]["project_data"]["TEST KEY"] == "TEST VALUE":
                found_new_object_as_child = True

    context.test_case.assertTrue(found_new_object_as_child)


@then("I get a project list and I can see the projects I do have viewer rights on")
def step(context):
    '''In the test dataset there is a project with read permission and another with all permissions - should be able to see both'''
    result = context.api_client.get(
        "/dev/datastore/cbh_projects_with_forms", format="json")
    context.test_case.assertValidJSON(result.content)
    try:
        has_no_viewer_project = result.content.index(
            '"/dev/datastore/cbh_projects_with_forms/5"')
        context.test_case.assertTrue(True)
    except ValueError:
        # Exception should throw
        # print (result.content)
        context.test_case.assertTrue(False)

    try:
        has_no_viewer_project = result.content.index(
            '"/dev/datastore/cbh_projects_with_forms/3"')
        context.test_case.assertTrue(True)
    except ValueError:
        # Exception should throw
        # print (result.content)
        context.test_case.assertTrue(False)


@then("I GET a list of classifications and it is empty because nothing has permissions")
def step(context):
    classif = context.api_client.get(
        "/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 0)


@then("I POST a new classification to my editor project and get 201")
def step(context):
    post_data = {"data_form_config": "/dev/datastore/cbh_data_form_config/5",
                 "l0": "/dev/datastore/cbh_datapoints/2",
                 "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/3"],
                 "l1": {"project_data": {"TEST KEY": "TEST VALUE"}, "custom_field_config": "/dev/datastore/cbh_custom_field_config/96"}}
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
                                      format="json",
                                      data=post_data)
    context.test_case.assertHttpCreated(created)


@then("I POST a new classification to my viewer project and get 401")
def step(context):
    post_data = {"data_form_config": "/dev/datastore/cbh_data_form_config/5",
                 "l0": "/dev/datastore/cbh_datapoints/2",
                 "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/5"],
                 "l1": {"project_data": {"TEST KEY": "TEST VALUE"}, "custom_field_config": "/dev/datastore/cbh_custom_field_config/96"}}
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
                                      format="json",
                                      data=post_data)
    context.test_case.assertHttpUnauthorized(created)


@then("I POST a new classification to the project I have no permissions on and get 401")
def step(context):
    post_data = {"data_form_config": "/dev/datastore/cbh_data_form_config/5",
                 "l0": "/dev/datastore/cbh_datapoints/2",
                 "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/4"],
                 "l1": {"project_data": {"TEST KEY": "TEST VALUE"}, "custom_field_config": "/dev/datastore/cbh_custom_field_config/96"}}
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
                                      format="json",
                                      data=post_data)
    context.test_case.assertHttpUnauthorized(created)


@then("I POST a new classification without linked project and get 400")
def step(context):
    post_data = {"data_form_config": "/dev/datastore/cbh_data_form_config/5",
                 "l0": "/dev/datastore/cbh_datapoints/2",
                 "l0_permitted_projects": [],
                 "l1": {"project_data": {"TEST KEY": "TEST VALUE"}, "custom_field_config": "/dev/datastore/cbh_custom_field_config/96"}}
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
                                      format="json",
                                      data=post_data)
    context.test_case.assertHttpBadRequest(created)


@given("a datapointclassification is linked to a project I do not have access to and another is in readonly")
def step(context):

    DataPointClassificationPermission.objects.create(
        project_id=3, data_point_classification_id=2)
    DataPointClassificationPermission.objects.create(
        project_id=4, data_point_classification_id=1)


@then("I get classifications and I see only 1 record from my readonly project")
def step(context):
    classif = context.api_client.get(
        "/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["objects"][0][
                                   "resource_uri"], "/dev/datastore/cbh_datapoint_classifications/2")
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)


@then("I request all data from the elasticsearch index and see only 1 record from my readonly project")
def step(context):
    classif = context.api_client.post("/dev/datastore/cbh_queries/_search?from=0&size=10",
                                      format="json", data={"query": {"match_all": {}}, "aggs": {}})

    classif = json.loads(classif.content)
    print (classif)
    context.test_case.assertEquals(classif["hits"]["hits"][0]["_source"][
                                   "resource_uri"], "/dev/datastore/cbh_datapoint_classifications/2")
    context.test_case.assertEquals(classif["hits"]["total"], 1)


@then("I reindex Elasticsearch")
def step(context):
    from cbh_datastore_ws.resources import reindex_datapoint_classifications
    reindex_datapoint_classifications()


@then("I GET data point classifications with nesting and filter only for objects without a parent (l0)")
def step(context):
    '''Here we are checking that the children data is available via the nested call'''
    result = context.api_client.get(
        "/dev/datastore/cbh_datapoint_classifications_nested?full=true&parent_id=None", format="json")
    context.test_case.assertValidJSON(result.content)
    data = json.loads(result.content)
    found_non_l0 = False
    print (data)
    for obj in data["objects"]:
        if obj["level_from"] != "l0":
            found_non_l0 = True

    context.test_case.assertFalse(found_non_l0)
    context.test_case.assertEquals(data["meta"]["total_count"], 1)
