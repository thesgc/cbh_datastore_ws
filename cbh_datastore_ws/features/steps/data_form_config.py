
import json


@then("The data_form_configs in the project output have permitted children and there is a single root object")
def step(context):
    classif = context.api_client.get(
        "/dev/api/datastore/cbh_projects_with_forms/?project_key=assayswithpermission")
    data = json.loads(classif.content)
    context.test_case.assertEquals(
        data["objects"][0]["data_form_configs"][0]["last_level"], "l0")
    context.test_case.assertEquals(data["objects"][0]["data_form_configs"][0][
                                   "permitted_children"], ["/dev/api/datastore/cbh_data_form_config/7"])
    context.test_case.assertEquals(data["meta"]["total_count"], 1)
