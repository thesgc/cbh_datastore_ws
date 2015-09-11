from behave import given, when, then
import json
from cbh_core_model.models import Project, CustomFieldConfig, PinnedCustomField, ProjectType, DataType, DataFormConfig
from cbh_datastore_model.models import DataPoint, DataPointClassification, DataPointClassificationPermission
from django.db import IntegrityError
from cbh_datastore_ws import parser
from collections import OrderedDict





@given("I create custom field configs based on the data given")
def step(context):


    setup = OrderedDict(
        [("l0", {"dtype": "Project", }),
        ("l1", {"dtype": "Sub-project",}),
        ("l2", {"dtype": "Assay"}),
        ("l3", {"dtype": "Activity"}),]
    )

    for level in setup.keys():
        setup[level]["dtypeobj"] = DataType.objects.get_or_create(name=setup[level]["dtype"],)
        defname = "%s data def" % setup[level]["dtype"]
        data = parser.get_custom_field_config("features/fixtures/sample_data.xlsx", defname)
        setup[level]["cfc"] = CustomFieldConfig.objects.create(name=defname, created_by=context.user, data_type=setup[level]["dtypeobj"][0])
        for index, d in enumerate(data):
            d["custom_field_config"] = setup[level]["cfc"]
            d["position"] = index
            setup[level]["cfc"].pinned_custom_field.add(PinnedCustomField.objects.create(**d))
        setup[level]["cfc"].save()
    df_args = {level: setup[level]["cfc"] for level in setup.keys()}
    df_args["created_by"] = context.user

    context.dfc = DataFormConfig.objects.create(**df_args )
    context.test_case.assertEqual(context.dfc.l4_id, None)




@given("I create a project and add the data")
def step(context):
    ptype= ProjectType.objects.get_or_create(name="Assay")
    project = Project.objects.create(name="Adam Hendry PhD (2010-2014)", 
        created_by=context.user, 
        custom_field_config_id=-1, 
        project_type=ptype[0],
        project_key="ahphd"
        )
    project.enabled_forms.add(context.dfc)
    project.save()

    l0_data = parser.get_sheet("features/fixtures/sample_data.xlsx", "Project")
    l0_datapoint = DataPoint.objects.create(custom_field_config=context.dfc.l0, project_data=l0_data[0],created_by=context.user, )
    l0_dpc = DataPointClassification.objects.create(l0_id=l0_datapoint.id, data_form_config=context.dfc, created_by=context.user, )
    DataPointClassificationPermission.objects.create(project=project,data_point_classification=l0_dpc)

    first_l1_data = parser.get_sheet("features/fixtures/sample_data.xlsx", "Sub-project")
    first_l1_datapoint = DataPoint.objects.create(custom_field_config=context.dfc.l1, project_data=first_l1_data[0], created_by=context.user)
    first_l1_dpc = DataPointClassification.objects.create(parent=l0_dpc, l0_id=l0_datapoint.id, l1_id=first_l1_datapoint.id, data_form_config=context.dfc, created_by=context.user )
    DataPointClassificationPermission.objects.create(project=project,data_point_classification=first_l1_dpc)

    second_l1_data = parser.get_sheet("features/fixtures/sample_data.xlsx", "Sub-project_2")
    second_l1_datapoint = DataPoint.objects.create(custom_field_config=context.dfc.l1, project_data=first_l1_data[0], created_by=context.user)
    second_l1_dpc = DataPointClassification.objects.create(parent=l0_dpc ,l0_id=l0_datapoint.id, l1_id=second_l1_datapoint.id, data_form_config=context.dfc, created_by=context.user)
    DataPointClassificationPermission.objects.create(project=project,data_point_classification=second_l1_dpc)



    for assay, parent in (
                            ("Alpha Screen",first_l1_dpc),
                            ( "Thermal Shift",first_l1_dpc),
                            ("Cell Viab",second_l1_dpc),
                            ( "Cell Viab 2",second_l1_dpc),
                            ( "Luciferase", second_l1_dpc)
                        ):
        assay_def = parser.get_sheet("features/fixtures/sample_data.xlsx", "%s assay definition" % assay)
        assay_def_dp = DataPoint.objects.create(custom_field_config=context.dfc.l2, project_data=assay_def[0], created_by=context.user)
        assay_def_dpc = DataPointClassification.objects.create(parent=parent, l0_id=l0_datapoint.id, l2_id=assay_def_dp.id ,l1_id=first_l1_datapoint.id, data_form_config=context.dfc, created_by=context.user )
        DataPointClassificationPermission.objects.create(project=project,data_point_classification=assay_def_dpc)

        for point in parser.get_sheet("features/fixtures/sample_data.xlsx", "%s raw data" % assay):
            activity_dp = DataPoint.objects.create(
                custom_field_config=context.dfc.l3, 
                project_data=point, 
                created_by=context.user)
            activity_dpc = DataPointClassification.objects.create(
                parent=assay_def_dpc, 
                l0_id=l0_datapoint.id, 
                l1_id=first_l1_datapoint.id, 
                l2_id=assay_def_dp.id ,
                l3_id=activity_dp.id,
                data_form_config=context.dfc, 
                created_by=context.user )           
            DataPointClassificationPermission.objects.create(project=project,data_point_classification=activity_dpc)
 