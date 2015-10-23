# -*- coding: utf-8 -*-
"""
"""
from behave import given, when, then
import json
from cbh_core_model.models import Project, CustomFieldConfig, PinnedCustomField, ProjectType
from cbh_datastore_model.models import DataPoint, DataPointClassification
from django.db import IntegrityError


@given("I create a project and add each sheet in turn")
def project(context):
    ptype = ProjectType.objects.get_or_create(name="Assay")
    project = Project.objects.create(name="Adam Hendry PhD (2010-2014)",
                                     created_by=context.user,
                                     custom_field_config_id=-1,
                                     project_type=ptype[0],
                                     project_key="ahphd"
                                     )
    project.enabled_forms.add(context.dfc)
    project.save()
    context.dfc.get_all_ancestor_objects( context)
    flow_file, created = FlowFile.objects.get_or_create(identifier="testflowfile", defaults={
            'original_filename': 'mytestflow.xlsx',
            'total_size': self.flowTotalSize,
            'total_chunks': self.flowTotalChunks,
        })
