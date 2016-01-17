# -*- coding: utf-8 -*-
"""
"""
from behave import given, when, then
import json
from cbh_core_model.models import Project, CustomFieldConfig, PinnedCustomField, ProjectType
from cbh_datastore_model.models import DataPoint, DataPointClassification
from django.db import IntegrityError

@given("I upload a file to flowfiles")
def step(context):
    with open("src/cbh_datastore_ws/cbh_datastore_ws/features/fixtures/sample_data.xlsx") as f:
        resp = context.dclient.post("/dev/flow/upload/", {"file": f, "flowChunkNumber": 1, 
            "flowChunkSize": 22222222, 
            "flowCurrentChunkSize": 137227,
            "flowTotalSize": 137227,
            "flowFilename": "newtest.xlsx",
            "flowIdentifier": "137227-newtestxlsx",
            "flowRelativePath": "newtest.xlsx",
            "flowTotalChunks": 1})
    resp = context.api_client.get("/dev/datastore/cbh_flowfiles/137227-newtestxlsx", 
        format="json", 
        follow=True)
