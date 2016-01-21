from behave import given, when, then
import json

from django.db import IntegrityError
from cbh_core_ws import parser
from collections import OrderedDict


@given("I create custom field configs based on the data given")
def create_realdata(context):
    from cbh_core_model.models import Project, CustomFieldConfig, PinnedCustomField, ProjectType, DataType, DataFormConfig
    from cbh_datastore_model.models import DataPoint, DataPointClassification, DataPointClassificationPermission
    setup = OrderedDict(
        [("l0", {"dtype": "Project", }),
         ("l1", {"dtype": "Sub-project", }),
         ("l2", {"dtype": "Assay"}),
         ("l3", {"dtype": "Activity"}), ]
    )

    for level in setup.keys():
        setup[level]["dtypeobj"] = DataType.objects.get_or_create(
            name=setup[level]["dtype"],)
        defname = "%s data def" % setup[level]["dtype"]
        data = parser.get_custom_field_config(
             "src/cbh_datastore_ws/cbh_datastore_ws/features/fixtures/sample_data.xlsx", defname)
        setup[level]["cfc"] = CustomFieldConfig.objects.create(
            name=defname, created_by=context.user, data_type=setup[level]["dtypeobj"][0])
        for index, d in enumerate(data):
            d["custom_field_config"] = setup[level]["cfc"]
            d["position"] = index
            if d["name"] == "IC50 value":
                d["field_type"] = "decimal"
            setup[level]["cfc"].pinned_custom_field.add(
                PinnedCustomField.objects.create(**d))
        setup[level]["cfc"].save()
    df_args = {level: setup[level]["cfc"] for level in setup.keys()}
    df_args["created_by"] = context.user

    context.dfc = DataFormConfig.objects.create(**df_args)
    context.test_case.assertEqual(context.dfc.l4_id, None)




@given("I create a project and add the forms")
def project(context):
    from cbh_core_model.models import Project, CustomFieldConfig, PinnedCustomField, ProjectType, DataType, DataFormConfig
    from cbh_datastore_model.models import DataPoint, DataPointClassification, DataPointClassificationPermission
    ptype = ProjectType.objects.get_or_create(name="Assay")
    




    perm = Project.objects.create(created_by=context.superuser, 
        name="AssaysWithoutPermission", 
        id=4, 
        project_type=ptype[0], 
        project_key="tester3", 
        custom_field_config_id=-1,)
    perm.enabled_forms.add(context.dfc)
    perm.save()

    p = Project.objects.create(created_by=context.superuser, name="AssaysReadOnly", id=5, project_type=ptype[0], project_key="tester2", custom_field_config_id=-1,)
    p.make_viewer(context.user)
    p.enabled_forms.add(context.dfc)
    p.save()
    ro = Project.objects.create(created_by=context.user, 
        name="AssaysWithPermission", 
        id=3, 
        project_type=ptype[0], 
        project_key="tester",
        custom_field_config_id=-1,)
    ro.enabled_forms.add(context.dfc)
    ro.save()
    proj = Project.objects.create(name="Adam Hendry PhD (2010-2014)",
                                     created_by=context.user,
                                     custom_field_config_id=-1,
                                     project_type=ptype[0],
                                     project_key="ahphd"
                                     )
    proj.enabled_forms.add(context.dfc)
    proj.save()
    proj.save()

    project = proj

    tree_builder = {}
    context.dfc.get_all_ancestor_objects(context,tree_builder=tree_builder)

