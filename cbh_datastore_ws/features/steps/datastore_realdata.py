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
            "features/fixtures/sample_data.xlsx", defname)
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


@given("I create a project and add the data")
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

    l0_data = parser.get_sheet("features/fixtures/sample_data.xlsx", "Project")
    l0_datapoint, created = DataPoint.objects.get_or_create(
        custom_field_config=context.dfc.l0, project_data=l0_data[0][0], created_by=context.user, )
    context.l0_dpc = DataPointClassification.objects.create(
         l0_id=l0_datapoint.id, data_form_config_id=4, created_by=context.user)
    DataPointClassificationPermission.objects.create(
        project=project, data_point_classification=context.l0_dpc)

    first_l1_data = parser.get_sheet(
        "features/fixtures/sample_data.xlsx", "Sub-project")
    first_l1_datapoint = DataPoint.objects.create(
        custom_field_config=context.dfc.l1, project_data=first_l1_data[0][0], created_by=context.user)
    context.first_l1_dpc = DataPointClassification.objects.create(
        parent=context.l0_dpc, l0_id=l0_datapoint.id, l1_id=first_l1_datapoint.id, data_form_config_id=3, created_by=context.user)
    DataPointClassificationPermission.objects.create(
        project=project, data_point_classification=context.first_l1_dpc)

    second_l1_data = parser.get_sheet(
        "features/fixtures/sample_data.xlsx", "Sub-project_2")
    second_l1_datapoint = DataPoint.objects.create(
        custom_field_config=context.dfc.l1, project_data=first_l1_data[0][0], created_by=context.user)
    context.second_l1_dpc = DataPointClassification.objects.create(
        parent=context.l0_dpc, l0_id=l0_datapoint.id, l1_id=second_l1_datapoint.id, data_form_config_id=3, created_by=context.user)
    DataPointClassificationPermission.objects.create(
        project=project, data_point_classification=context.second_l1_dpc)

    for assay, parent in (
        ("Alpha Screen", context.first_l1_dpc),
        ("Thermal Shift", context.first_l1_dpc),
        ("Cell Viab", context.second_l1_dpc),
        ("Cell Viab 2", context.second_l1_dpc),
        ("Luciferase", context.second_l1_dpc)
    ):
        assay_def = parser.get_sheet(
            "features/fixtures/sample_data.xlsx", "%s assay definition" % assay)
        assay_def_dp = DataPoint.objects.create(
            custom_field_config=context.dfc.l2, project_data=assay_def[0][0], created_by=context.user)
        assay_def_dpc = DataPointClassification.objects.create(
            parent=parent, l0_id=l0_datapoint.id, l2_id=assay_def_dp.id, l1_id=first_l1_datapoint.id, data_form_config_id=2, created_by=context.user)
        DataPointClassificationPermission.objects.create(
            project=project, data_point_classification=assay_def_dpc)

        for point in parser.get_sheet("features/fixtures/sample_data.xlsx", "%s raw data" % assay)[0]:
            activity_dp = DataPoint.objects.create(
                custom_field_config=context.dfc.l3,
                project_data=point,
                created_by=context.user)
            context.activity_dpc = DataPointClassification.objects.create(
                parent=assay_def_dpc,
                l0_id=l0_datapoint.id,
                l1_id=first_l1_datapoint.id,
                l2_id=assay_def_dp.id,
                l3_id=activity_dp.id,
                data_form_config=context.dfc,
                created_by=context.user)
            DataPointClassificationPermission.objects.create(
                project=project, data_point_classification=context.activity_dpc)
