from behave import given, when, then
import json
from cbh_core_model.models import Project, CustomFieldConfig, PinnedCustomField, ProjectType
from cbh_datastore_model.models import DataPoint, DataPointClassification
from django.db import IntegrityError
import time


@then("appropriate post data When I create a single record If I post the same data back no Object is created")
def step(context):
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 0)

    post_data = {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
                "l0": {"custom_field_config":{"id":577},"project_data":{"some_test":"project_data"}},
                "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/3"] }
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
format="json", 
data= post_data)
    

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)

    data = json.loads(created.content)
    post_data["id"] = data["id"]
    post_data["resource_uri"] = data["resource_uri"]
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
format="json", 
data= post_data)
    print (created.content)

    
    d = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")

    classif = json.loads(d.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)



@then("I post the original data back with the new datapoint id no record is created and there is an error")
def step(context):
    """
    """
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 0)

    post_data = {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
                "l0": {
                "custom_field_config":{"id":577},"project_data":{"some_test":"project_data"}},
                "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/3"] }
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
format="json", 
data= post_data)

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)
    data = json.loads(created.content)

    post_data["l0"]["id"] = data["l0"]["id"]
    integerror = False
    try:
        created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
    format="json", 
    data= post_data)
    except IntegrityError:
        integerror = True
    context.test_case.assertTrue(integerror)
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)


@then("I create a single recordIf I post the original data back with the new URI no record is created and there is an error")
def step(context):
    
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 0)

    post_data = {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
                "l0": {"custom_field_config":{"id":577},"project_data":{"some_test":"project_data"}},
                "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/3"] }
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
format="json", 
data= post_data)

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)
    data = json.loads(created.content)

    #To post resource uris we just pass a string
    post_data["l0"] = data["l0"]["resource_uri"]
    integerror = False
    try:
        created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
    format="json", 
    data= post_data)
    except IntegrityError:
        integerror = True
    context.test_case.assertTrue(integerror)

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)




@then("When I create a single record If I patchb the same data back, updating the l0 datapoint then only the l0 data point changes")
def step(context):
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 0)

    post_data = {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
                "l0": {"custom_field_config":{"id":577},"project_data":{"some_test":"project_data"}},
                "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/3"] }
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
format="json", 
data= post_data)

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)

    data = json.loads(created.content)
    post_data["l0"]["project_data"]["newtestvalue"] ="newtest"
    post_data["l0"]["id"] =  data["l0"]["id"]
    post_data["id"] = data["id"]
    updated = context.api_client.patch("/dev/datastore/cbh_datapoint_classifications/%d" % data["id"],
format="json", 
data= post_data)
    print (updated.content)

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)
    context.test_case.assertEquals(data["resource_uri"], json.loads(updated.content)["resource_uri"])

    context.test_case.assertHttpAccepted(updated)


    dps = context.api_client.get("/dev/datastore/cbh_datapoints/%d" % data["l0"]["id"])
    dpsdata = json.loads(dps.content)
    context.test_case.assertEquals(dpsdata["project_data"]["newtestvalue"],"newtest")




@then("When I create a single record If I patch the same data back, updating one of the default datapoints then there is an error due to conflict")
def step(context):

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 0)

    post_data = {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
                "l0": {"custom_field_config":{"id":577},"project_data":{"some_test":"project_data"}},
                "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/3"] }
    created = context.api_client.post("/dev/datastore/cbh_datapoint_classifications",
format="json", 
data= post_data)

    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)

    data = json.loads(created.content)

    post_data["l1"] = data["l1"]
    post_data["l0"] = data["l0"]
    # post_data["l0"]["custom_field_config"] = post_data["l0"]["custom_field_config"]["resource_uri"]
    post_data["l1"]["project_data"]["newtestvalue"] ="newtest"
    post_data.pop("created_by", None)
    post_data["l1"].pop("created_by", None)
    post_data["l0"].pop("created_by", None)
    print(post_data)
    updated = context.api_client.patch("/dev/datastore/cbh_datapoint_classifications/%d" % data["id"],
format="json", 
data= post_data)

    context.test_case.assertHttpConflict(updated)
    classif = context.api_client.get("/dev/datastore/cbh_datapoint_classifications")
    classif = json.loads(classif.content)
    context.test_case.assertEquals(classif["meta"]["total_count"], 1)


@then("If I patch an l0 update which affects multiple datapoint classifications the index updates to reflect")
def step(context):
    print("THIS TEST NEEDS ADDING")
    context.test_case.assertEquals(False, True)