# -*- coding: utf-8 -*-
"""steps/browser_steps.py -- step implementation for our browser feature demonstration.
"""
from behave import given, when, then
import json
from cbh_core_model.models import Project, CustomFieldConfig, PinnedCustomField, ProjectType, DataPoint, DataPointClassification


@given('the project is configured for a simple assay and bioactivity')
def step(context):
    proj, created = Project.objects.get_or_create(name="proja", created_by=context.u)
    cfc, cre = CustomFieldConfig.objects.get_or_create(name="Assay", created_by=context.u)
    proj.custom_field_config = cfc
    proj.save()
    data = {"form": [{"field_type": "char", "title": "Description", "allowed_values": "", "key": "Description", "position": 0, "placeholder": "", "part_of_blinded_key": False}, {"field_type": "char", "title": "Assay Type", "allowed_values": "", "key": "Assay Type", "position": 1, "placeholder": "", "part_of_blinded_key": False}, {"field_type": "char", "title": "Cell line / tissue", "allowed_values": "", "key": "Cell line / tissue", "position": 2, "placeholder": "", "part_of_blinded_key": False}, {"field_type": "char", "title": "Target type", "allowed_values": "", "key": "Target type", "position": 3, "placeholder": "", "part_of_blinded_key": False}, {"field_type": "char", "title": "Model organism", "allowed_values": "", "key": "Model organism", "position": 4, "placeholder": "", "part_of_blinded_key": False}, {"field_type": "char", "title": "Target name", "allowed_values": "", "key": "Target name", "position": 5, "placeholder": "", "part_of_blinded_key": False}, {"field_type": "char", "title": "UniProt ID", "allowed_values": "", "key": "UniProt ID", "position": 6, "placeholder": "", "part_of_blinded_key": False}, {"field_type": "char", "title": "Target Organism", "allowed_values": "", "key": "Target Organism", "position": 7, "placeholder": "", "part_of_blinded_key": False}, {"field_type": "char", "title": "References (DOI)", "allowed_values": "", "key": "References (DOI)", "position": 8, "placeholder": "", "part_of_blinded_key": False}], "schema": {"required": [], "type": "object", "properties": {"Assay Type": {"friendly_field_type": "Short text field", "placeholder": "", "type": "string", "title": "Assay Type"}, "Description": {"friendly_field_type": "Short text field", "placeholder": "", "type": "string", "title": "Description"}, "Target type": {"friendly_field_type": "Short text field", "placeholder": "", "type": "string", "title": "Target type"}, "Target name": {"friendly_field_type": "Short text field", "placeholder": "", "type": "string", "title": "Target name"}, "Target Organism": {"friendly_field_type": "Short text field", "placeholder": "", "type": "string", "title": "Target Organism"}, "References (DOI)": {"friendly_field_type": "Short text field", "placeholder": "", "type": "string", "title": "References (DOI)"}, "Model organism": {"friendly_field_type": "Short text field", "placeholder": "", "type": "string", "title": "Model organism"}, "Cell line / tissue": {"friendly_field_type": "Short text field", "placeholder": "", "type": "string", "title": "Cell line / tissue"}, "UniProt ID": {"friendly_field_type": "Short text field", "placeholder": "", "type": "string", "title": "UniProt ID"}}}}

    for position, field in enumerate(data["form"]):
        PinnedCustomField.objects.create(allowed_values=field["allowed_values"],
                                        custom_field_config=cfc,
                                        field_type=field["field_type"],
                                        position=field["position"],
                                        name=field["key"],
                                        description=field["placeholder"])

    cfc2, cre = CustomFieldConfig.objects.get_or_create(name="BioActivity", created_by=context.u)


    data2 = {"form": [{"field_type": "number", "title": "IC50 (nm)", "allowed_values": "", "key": "IC50 (nm)", "position": 0, "placeholder": "", "part_of_blinded_key": False}], "schema": {"required": [], "type": "object", "properties": {"IC50 (nm)": {"friendly_field_type": "Decimal field", "placeholder": "", "title": "IC50 (nm)", "type": "number", "icon": "<span class ='glyphicon glyphicon-sound-5-1'></span>"}}}}


    for position, field in enumerate(data2["form"]):
        PinnedCustomField.objects.create(allowed_values=field["allowed_values"],
                                        custom_field_config=cfc2,
                                        field_type=field["field_type"],
                                        position=field["position"],
                                        name=field["key"],
                                        description=field["placeholder"])

    ProjectType.objects.create(name="myassay", level_0=cfc, level_1=cfc2)
    dp1 = DataPoint.objects.create(created_by=context.u, project_data={"Description" : "Test Assay"})
    dp2 = DataPoint.objects.create(created_by=context.u, project_data={"IC50 (nm)" : 50})

    classification = DataPointClassification.objects.create(project=proj, l1=dp1, l2=dp2, created_by=context.u)