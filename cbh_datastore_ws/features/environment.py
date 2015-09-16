# -*- coding: utf-8 -*-
from __future__ import unicode_literals
import time

"""environment -- environmental setup for Django+Behave+Mechanize

This should go in features/environment.py
(http://packages.python.org/behave/tutorial.html#environmental-controls)

Requirements:
http://pypi.python.org/pypi/behave/
http://pypi.python.org/pypi/mechanize/
http://pypi.python.org/pypi/wsgi_intercept
http://pypi.python.org/pypi/BeautifulSoup/

Acknowledgements:
For the basic solution: https://github.com/nathforge/django-mechanize/

  %load_ext autoreload
%autoreload 2
from tastypie.test import TestApiClient
api_client = TestApiClient()
from django.test.simple import DjangoTestSuiteRunner
runner = DjangoTestSuiteRunner(interactive=False)
runner.setup_test_environment()
runner.setup_databases()



api_client.client.login(username="tester",password="tester")


#Feature new project adding first assay

# @step("List the forms that are configured for proja")

import json

result = api_client.client.get("/dev/datastore/cbh_projects_with_forms")

data = json.loads(result.content)

#Select the first project and the first of the enabled forms from that project then check that the form URI is as expected
assertEquals(data["objects"][0]["enabled_forms"][0], u"/dev/datastore/cbh_data_form_config/4")


#@step("User picks a form (e.g. ic50 study) and sees that there is no data for that study")


#Assume that the user has picked the uri of the data form
#Search the data point classifications for those that have been registered for this project
classif = api_client.client.get("/dev/datastore/cbh_datapoint_classifications?data_form_config_id=4")
classif = json.loads(classif.content)
assertEquals(classif["meta"]["total_count"], 0)

#@step("User fills in the first top level form and submits it")
#System selects the custom field config information for the datapoint that will be connected to l0


cf_config_for_l0 = data["objects"][0]["enabled_forms"][0]["l0"]

#Submit a DataPoint (we don't need to do this)

post_data = {"project_data": {}, "supplementary_data" : {}, "custom_field_config" : cf_config_for_l0 }


#Submit a full datapoint classification

post_data = {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
    "l0": {"custom_field_config":{"pk":577},"project_data":{"some_test":"project_data"}},
    "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] }
created = api_client.post("/dev/datastore/cbh_datapoint_classifications",
    format="json", 
    data= post_data)

#Get the id from the submitted data 


#@step("system now lists the new study")

#@step - user tries to submit the same study again
created = api_client.post("/dev/datastore/cbh_datapoint_classifications",
    format="json", 
    data= {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
    "l0": "/dev/datastore/cbh_datapoints/37",  
    "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] })

#@step("user now uses the second level form to submit two child objects to the new study")

#We submit 

created = api_client.post("/dev/datastore/cbh_datapoint_classifications",
    format="json", 
    data= {"data_form_config":"/dev/datastore/cbh_data_form_config/4", 
    "l0": {"custom_field_config":{"pk":577}},
    "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] })



"""


import os, django
import urlparse
# This is necessary for all installed apps to be recognized, for some reason.
#Already set this on vagrant
#os.environ['DJANGO_SETTINGS_MODULE'] = 'myproject.settings'
from tastypie.test import TestApiClient
from tastypie.serializers import Serializer
from tastypie.test import ResourceTestCase
from django.conf import settings
from django.test import TestCase
from django.test.client import FakePayload, Client
from django.utils.encoding import force_text

from tastypie.serializers import Serializer

try:
    from urllib.parse import urlparse
except ImportError:
    from urlparse import urlparse
import unittest

class Tester(unittest.TestCase):
    # def assertEqual(a,b):
    #     return assert(a==b)

    def runTest(self):
        pass

    def assertHttpOK(self, resp):
        """
        Ensures the response is returning a HTTP 200.
        """
        return self.assertEqual(resp.status_code, 200)

    def assertHttpCreated(self, resp):
        """
        Ensures the response is returning a HTTP 201.
        """
        return self.assertEqual(resp.status_code, 201)

    def assertHttpAccepted(self, resp):
        """
        Ensures the response is returning either a HTTP 202 or a HTTP 204.
        """
        return self.assertIn(resp.status_code, [202, 204])

    def assertHttpMultipleChoices(self, resp):
        """
        Ensures the response is returning a HTTP 300.
        """
        return self.assertEqual(resp.status_code, 300)

    def assertHttpSeeOther(self, resp):
        """
        Ensures the response is returning a HTTP 303.
        """
        return self.assertEqual(resp.status_code, 303)

    def assertHttpNotModified(self, resp):
        """
        Ensures the response is returning a HTTP 304.
        """
        return self.assertEqual(resp.status_code, 304)

    def assertHttpBadRequest(self, resp):
        """
        Ensures the response is returning a HTTP 400.
        """
        return self.assertEqual(resp.status_code, 400)

    def assertHttpUnauthorized(self, resp):
        """
        Ensures the response is returning a HTTP 401.
        """
        return self.assertEqual(resp.status_code, 401)

    def assertHttpForbidden(self, resp):
        """
        Ensures the response is returning a HTTP 403.
        """
        return self.assertEqual(resp.status_code, 403)

    def assertHttpNotFound(self, resp):
        """
        Ensures the response is returning a HTTP 404.
        """
        return self.assertEqual(resp.status_code, 404)

    def assertHttpMethodNotAllowed(self, resp):
        """
        Ensures the response is returning a HTTP 405.
        """
        return self.assertEqual(resp.status_code, 405)

    def assertHttpConflict(self, resp):
        """
        Ensures the response is returning a HTTP 409.
        """
        return self.assertEqual(resp.status_code, 409)

    def assertHttpGone(self, resp):
        """
        Ensures the response is returning a HTTP 410.
        """
        return self.assertEqual(resp.status_code, 410)

    def assertHttpUnprocessableEntity(self, resp):
        """
        Ensures the response is returning a HTTP 422.
        """
        return self.assertEqual(resp.status_code, 422)

    def assertHttpTooManyRequests(self, resp):
        """
        Ensures the response is returning a HTTP 429.
        """
        return self.assertEqual(resp.status_code, 429)

    def assertHttpApplicationError(self, resp):
        """
        Ensures the response is returning a HTTP 500.
        """
        return self.assertEqual(resp.status_code, 500)

    def assertHttpNotImplemented(self, resp):
        """
        Ensures the response is returning a HTTP 501.
        """
        return self.assertEqual(resp.status_code, 501)

    def assertValidJSON(self, data):
        """
        Given the provided ``data`` as a string, ensures that it is valid JSON &
        can be loaded properly.
        """
        # Just try the load. If it throws an exception, the test case will fail.
        import json
        json.loads(data)

    def assertValidXML(self, data):
        """
        Given the provided ``data`` as a string, ensures that it is valid XML &
        can be loaded properly.
        """
        # Just try the load. If it throws an exception, the test case will fail.
        self.serializer.from_xml(data)

    def assertValidYAML(self, data):
        """
        Given the provided ``data`` as a string, ensures that it is valid YAML &
        can be loaded properly.
        """
        # Just try the load. If it throws an exception, the test case will fail.
        self.serializer.from_yaml(data)

    def assertValidPlist(self, data):
        """
        Given the provided ``data`` as a string, ensures that it is valid
        binary plist & can be loaded properly.
        """
        # Just try the load. If it throws an exception, the test case will fail.
        self.serializer.from_plist(data)

    def assertValidJSONResponse(self, resp):
        """
        Given a ``HttpResponse`` coming back from using the ``client``, assert that
        you get back:
        * An HTTP 200
        * The correct content-type (``application/json``)
        * The content is valid JSON
        """
        self.assertHttpOK(resp)
        self.assertTrue(resp['Content-Type'].startswith('application/json'))
        self.assertValidJSON(force_text(resp.content))

    def assertValidXMLResponse(self, resp):
        """
        Given a ``HttpResponse`` coming back from using the ``client``, assert that
        you get back:
        * An HTTP 200
        * The correct content-type (``application/xml``)
        * The content is valid XML
        """
        self.assertHttpOK(resp)
        self.assertTrue(resp['Content-Type'].startswith('application/xml'))
        self.assertValidXML(force_text(resp.content))

    def assertValidYAMLResponse(self, resp):
        """
        Given a ``HttpResponse`` coming back from using the ``client``, assert that
        you get back:
        * An HTTP 200
        * The correct content-type (``text/yaml``)
        * The content is valid YAML
        """
        self.assertHttpOK(resp)
        self.assertTrue(resp['Content-Type'].startswith('text/yaml'))
        self.assertValidYAML(force_text(resp.content))

    def assertValidPlistResponse(self, resp):
        """
        Given a ``HttpResponse`` coming back from using the ``client``, assert that
        you get back:
        * An HTTP 200
        * The correct content-type (``application/x-plist``)
        * The content is valid binary plist data
        """
        self.assertHttpOK(resp)
        self.assertTrue(resp['Content-Type'].startswith('application/x-plist'))
        self.assertValidPlist(force_text(resp.content))
 
import os

def before_all(context):
    from cbh_datastore_ws.features.steps.datastore_realdata import create_realdata, project

    pass
    # Even though DJANGO_SETTINGS_MODULE is set, this may still be
    # necessary. Or it may be simple CYA insurance.

    # We'll use thise later to frog-march Django through the motions
    # of setting up and tearing down the test environment, including
    # test databases.
    # from django.core.management import setup_environ
    # from deployment.settings  import development as settings
    # setup_environ(settings)
    #os.environ.setdefault("DJANGO_SETTINGS_MODULE", "myapp.settings")

    # context.runner.setup_databases()
    # from django.core.management import call_command
    # # from django.contrib.contenttypes.models import ContentType
    # # ContentType.objects.all().delete()
    # from cbh_core_model.models import Project, CustomFieldConfig
    # # Project.objects.all().delete()
    # call_command("loaddata", "/home/vagrant/chembiohub_ws/src/cbh_datastore_ws/cbh_datastore_ws/features/fixtures/newtestfixture.json")



def before_scenario(context, scenario):
    # Set up the scenario test environment
    from subprocess import Popen, PIPE, call

    call("echo 'drop database if exists tester_cbh_chembl;create database tester_cbh_chembl;'  | psql template1 >/dev/null", shell=True)
    call("psql -Uchembl tester_cbh_chembl < features/fixtures/testreg.sql >/dev/null", shell=True)

    django.setup()
    from cbh_datastore_ws.elasticsearch_client import delete_main_index
    delete_main_index()

    # django.setup()

    ### Take a TestRunner hostage.
    from django.test.simple import DjangoTestSuiteRunner
    context.runner = DjangoTestSuiteRunner(interactive=False)
    
    ## If you use South for migrations, uncomment this to monkeypatch
    ## syncdb to get migrations to run.
    #from south.management.commands import patch_for_test_db_setup
    #patch_for_test_db_setup()

    
    # context.runner.setup_test_environment()
    ### Set up the WSGI intercept "port".
    context.api_client = TestApiClient()
    context.test_case =  Tester()
    
    from cbh_chembl_model_extension.models import CBHCompoundBatch
    from cbh_core_model.models import Project, CustomFieldConfig
    from cbh_datastore_model.models import DataPoint, DataPointClassification

    from django.contrib.auth.models import User, Group

    context.response = None
    context.user = User.objects.get(username="testuser")
    context.runner.setup_test_environment()




def after_scenario(context, scenario):
    # Tear down the scenario test environment.
    #context.runner.teardown_databases(context.old_db_config)


    context.api_client.client.logout()
    from django import db
    db.close_connection()
    from subprocess import call
    # call("echo 'drop database if exists tester_cbh_chembl;'  | psql template1 >/dev/null", shell=True)

    # User.objects.all().exclude(id=-1).delete()
    # CustomFieldConfig.objects.exclude(id=-1).all().delete()
    # Group.objects.all().delete()
    # CBHCompoundBatch.objects.all().delete()
    # DataPointClassification.objects.all().delete()
    # DataPoint.objects.exclude(id=1).delete()
    # context.runner.teardown_test_environment()
    # Bob's your uncle.

def after_all(context):
    from cbh_datastore_model.models import      DataPointClassificationPermission, DataPointClassification
    from cbh_datastore_ws.resources import reindex_datapoint_classifications
    from cbh_datastore_ws.features.steps.datastore_realdata import create_realdata, project
    from cbh_datastore_ws.features.steps.permissions import logintestuser
    before_scenario(context, None)
    logintestuser(context)
    create_realdata(context)
    project(context)

    from cbh_chembl_ws_extension.parser import ChemblAPIConverter

    ChemblAPIConverter().write_schema()
    reindex_datapoint_classifications()
    context.api_client.client.logout()
    from django import db
    db.close_connection()
