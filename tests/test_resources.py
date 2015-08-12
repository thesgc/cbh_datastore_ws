#Tests to implement

'''


'''
from django.db import IntegrityError

import datetime
from django.contrib.auth.models import User
from tastypie.test import ResourceTestCase
from cbh_chembl_model_extension.models import CBHCompoundBatch
from cbh_core_model.models import Project
from django.db import connection
import json

class DataStoreResourceTest(ResourceTestCase):
    # Use ``fixtures`` & ``urls`` as normal. See Django's ``TestCase``
    # documentation for the gory details.
    #fixtures = ['test_entries.json']

    def setUp(self):
        super(DataStoreResourceTest, self).setUp()
        # Create a user.
        self.username = 'tester'
        self.password = 'tester'
        from django.core.management import call_command
        call_command("loaddata", "src/cbh_datastore_ws/cbh_datastore_ws/features/fixtures/test_fixtures.json")



 
    def setup_session(self):
        self.api_client.client.login(username=self.username, password=self.password)
        




