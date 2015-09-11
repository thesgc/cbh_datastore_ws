
import json
@then("The data form configs in the enabled forms list of a project have keys to allow routes through the system to be presented to the user")
def step(context):
    classif = context.api_client.get("/dev/datastore/cbh_projects_with_forms/?project_key=assayswithpermission")
    data = json.loads(classif.content)
    context.test_case.assertEquals(data["objects"][0]["enabled_forms"][0]["l3_key"], "106_107_114_115")
    context.test_case.assertEquals(data["objects"][0]["enabled_forms"][0]["l2_key"], "106_107_114")
    context.test_case.assertEquals(data["objects"][0]["enabled_forms"][0]["l1_key"], "106_107")
    context.test_case.assertEquals(data["objects"][0]["enabled_forms"][0]["l0_key"], "106")
    context.test_case.assertEquals(data["meta"]["total_count"], 1)
