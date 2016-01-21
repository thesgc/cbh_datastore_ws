# -*- coding: utf-8 -*-
import logging

# Get an instance of a logger
logger = logging.getLogger(__name__)


from django_rq import job
from django.conf.urls import url
import json
from tastypie.resources import ModelResource, Resource, ALL, ALL_WITH_RELATIONS
from django.core.exceptions import ObjectDoesNotExist
from tastypie.serializers import Serializer
from cbh_core_ws.resources import UserResource
from cbh_datastore_model.models import DataPoint, DataPointClassification, DataPointClassificationPermission, Query, Attachment
from cbh_core_model.models import CustomFieldConfig
from cbh_core_model.models import DataFormConfig
from cbh_core_model.models import PinnedCustomField
from cbh_core_model.models import Project
from cbh_core_ws.serializers import ResultsExportXLSSerializer
from tastypie import fields
from tastypie.authentication import SessionAuthentication
from django.contrib.auth import get_user_model
from fuzzywuzzy import fuzz
import time
from tastypie.exceptions import BadRequest

from tastypie.authorization import Authorization
from tastypie.http import HttpConflict
from tastypie.exceptions import ImmediateHttpResponse

from cbh_datastore_ws.authorization import DataClassificationProjectAuthorization

from cbh_core_ws.authorization import ProjectListAuthorization
from django.http import HttpResponse

from copy import copy

from tastypie.utils.mime import build_content_type

from tastypie import http

from cbh_datastore_ws import elasticsearch_client
from cbh_datastore_ws.serializers import DataPointClassificationSerializer

from django.db.models import Max, Min
from django.http import HttpRequest
from cbh_core_ws.parser import get_sheetnames, get_sheet

from flowjs.models import FlowFile
from django.conf import settings

import importlib
import six

from cbh_core_ws.cache import CachedResource
from cbh_core_ws.serializers import CustomFieldXLSSerializer
from xlrd.biffh import XLRDError
from cbh_core_ws.resources import SimpleResourceURIField, UserHydrate, CBHDictField
 


class FlowFileResource(ModelResource):
    sheet_names = fields.ListField()

    class Meta:
        detail_uri_name = 'identifier'
        # Must be false to not give secret key away
        include_resource_uri = False
        allowed_methods = ['get', ]
        resource_name = 'cbh_flowfiles'
        queryset = FlowFile.objects.all()
        filtering = {"identifier": ALL_WITH_RELATIONS}

    def dehydrate_sheet_names(self, bundle):
        try:
            sheetnames = get_sheetnames(bundle.obj.path)
            return sheetnames
        except XLRDError:
            raise BadRequest("Incorrect format or corrupt file")

    def obj_get(self, bundle, **applicable_filters):
        """
        An ORM-specific implementation of ``apply_filters``.
        The default simply applies the ``applicable_filters`` as ``**kwargs``,
        but should make it possible to do more advanced things.
        """
        if applicable_filters.get("identifier", None):
            applicable_filters["identifier"] = "%s-%s" % (
                bundle.request.COOKIES.get(settings.SESSION_COOKIE_NAME, "None"), applicable_filters["identifier"])
        return super(FlowFileResource, self).obj_get(bundle, **applicable_filters)


class StandardisedForeignKey(fields.ForeignKey):

    def should_full_dehydrate(self, bundle, for_list):
        return bundle.request.GET.get("standardised", None)


class DataPointProjectFieldResource(ModelResource):

    """Provides the schema information about a field that is required by front end apps"""
    handsontable_column = CBHDictField(
        null=True, blank=False, help_text=None)
    edit_form = CBHDictField(
        null=True, blank=False,  help_text=None)
    edit_schema = CBHDictField(
        null=True, blank=False,  help_text=None)
    elasticsearch_fieldname = fields.CharField(
        null=True, blank=False,  help_text=None)
    standardised_alias = SimpleResourceURIField('self',
        attribute="standardised_alias_id", null=True, blank=False,  help_text=None)
    attachment_field_mapped_to = SimpleResourceURIField('self',
        attribute="attachment_field_mapped_to_id", null=True, blank=False,  help_text=None)

    class Meta:
        queryset = PinnedCustomField.objects.all()
        always_return_data = True
        resource_name = 'cbh_datapoint_fields'
        include_resource_uri = True
        allowed_methods = ['get', 'post', 'patch', 'put']
        default_format = 'application/json'
        authentication = SessionAuthentication()
        authorization = Authorization()
        level = None
        description = {'api_dispatch_detail' : '''
Provides information about the data types present in the flexible schema of the datapoint table
For each field a set of attributes are returned:

hide_form/schema - an angular schema form element that can be used to hide this column from view
edit_form /schema - an angular schema form element that can be used to edit this field 

assuming it is edited as part of a larger data form classification object
- To change the key of the json schema then change the get_namespace method

filter_form/schema - an angular schema form element that can be used to hide this filter this field

exclude_form /schema an angular schema form element that can be used to hide this exclude values from this field

sort_form /schema an angular schema form element that can be used to hide this exclude values from this field

Things still to be implemented:

actions form - would be used for mapping functions etc
autocomplete urls
        ''',

                       'api_dispatch_list' : '''
Provides information about the data types present in the flexible schema of the datapoint table
For each field a set of attributes are returned:

hide_form/schema - an angular schema form element that can be used to hide this column from view
edit_form /schema - an angular schema form element that can be used to edit this field 

assuming it is edited as part of a larger data form classification object
- To change the key of the json schema then change the get_namespace method

filter_form/schema - an angular schema form element that can be used to hide this filter this field

exclude_form /schema an angular schema form element that can be used to hide this exclude values from this field

sort_form /schema an angular schema form element that can be used to hide this exclude values from this field

Things still to be implemented:

actions form - would be used for mapping functions etc
autocomplete urls
        '''
         }



    def is_authenticated(self, request):
        """
        Handles checking if the user is authenticated and dealing with
        unauthenticated users.

        Mostly a hook, this uses class assigned to ``authentication`` from
        ``Resource._meta``.
        """
        # Authenticate the request as needed.
        return True

  
    def hydrate_attachment_field_mapped_to(self, bundle):
        '''Preprocess the attachment custom field config to check that the chosen field matches properly'''
        if bundle.data["attachment_field_mapped_to"]:
            related_bundle = self.build_bundle(request=bundle.request,obj=self.get_via_uri(bundle.data["attachment_field_mapped_to"]))
            dehydr = self.full_dehydrate(related_bundle) 
            bundles = ((bundle, dehydr),)
            attachment = Attachment.objects.filter(attachment_custom_field_config_id=bundle.obj.custom_field_config_id)[0]
            ar = AttachmentResource()
            attachment_json = json.loads(
                ar.get_detail(bundle.request, pk=attachment.id).content)
            hits = ar.retrieve_temp_data(  bundle.request, attachment_json)
            test_fields(bundles, [dictionary for dictionary in hits])
        return bundle


    def save(self, bundle, skip_errors=False):
        # if bundle.via_uri:
        #     return bundle

        self.is_valid(bundle)

        if bundle.errors and not skip_errors:
            raise ImmediateHttpResponse(response=self.error_response(bundle.request, bundle.errors))

        # Check if they're authorized.
        # if bundle.obj.pk:
        #     self.authorized_update_detail(self.get_object_list(bundle.request), bundle)
        # else:
        #     self.authorized_create_detail(self.get_object_list(bundle.request), bundle)

        # Save FKs just in case.
        self.save_related(bundle)

        # Save the main object.
        obj_id = self.create_identifier(bundle.obj)
       
        if obj_id not in bundle.objects_saved or bundle.obj._state.adding:
            bundle.obj.save()
            bundle.objects_saved.add(obj_id)

        # Now pick up the M2M bits.
        m2m_bundle = self.hydrate_m2m(bundle)
        self.save_m2m(m2m_bundle)
        return bundle

    def get_schema(self, request, **kwargs):
        """
        Returns a serialized form of the schema of the resource.
        Calls ``build_schema`` to generate the data. This method only responds
        to HTTP GET.
        Should return a HttpResponse (200 OK).
        """
        # self.method_check(request, allowed=['get'])
        # self.is_authenticated(request)
        # self.throttle_check(request)
        # self.log_throttled_access(request)
        # bundle = self.build_bundle(request=request)
        # self.authorized_read_detail(self.get_object_list(bundle.request), bundle)
        return self.create_response(request, self.build_schema())

    def get_namespace(self, bundle):
        '''
            Hook to return the dotted path to this field based on the level and the name of the field
            The level name is formatted in the dehydrate method of the DataFormConfigResource
        '''
        return "{level}.project_data.%s" % (bundle.obj.get_space_replaced_name)

    def get_namespace_for_action_key(self, bundle, action_type):
        return action_type

    def dehydrate_elasticsearch_fieldname(self, bundle):
        return bundle.obj.get_space_replaced_name

    def dehydrate_edit_form(self, bundle):
        '''          '''
        if bundle.request.GET.get("empty", False):
            return {}
        return {"form": [bundle.obj.field_values[1]]}

    def dehydrate_edit_schema(self, bundle):
        '''          '''
        if bundle.request.GET.get("empty", False):
            return {}
        return {"properties": {bundle.obj.get_space_replaced_name: bundle.obj.field_values[0]}}

    def dehydrate_handsontable_column(self, bundle):

        hotobj = {"title": bundle.obj.name,
                  "data": self.get_namespace(bundle),
                  "className": "htCenter htMiddle ",
                  "renderer": "linkRenderer"}

        return hotobj

    def authorized_update_detail(self, object_list, bundle):
        """
        Handles checking of permissions to see if the user has authorization
        to PUT this resource.
        """

        return True

    def authorized_create_detail(self, object_list, bundle):
        """
        Handles checking of permissions to see if the user has authorization
        to PUT this resource.
        """

        return True

class SimpleCustomFieldConfigResource(UserHydrate, ModelResource):

    '''Return only the project type and custom field config name as returning the full field list would be '''
    data_type = fields.ForeignKey("cbh_core_ws.resources.DataTypeResource",
                                  'data_type', readonly=True, null=True, blank=False, default=None, full=True)
    project_data_fields = fields.ToManyField("cbh_datastore_ws.resources.DataPointProjectFieldResource", lambda bundle: PinnedCustomField.objects.filter(
        custom_field_config_id=bundle.obj.id
    ), readonly=True, null=True, blank=False, default=None, full=True)
    created_by = fields.ForeignKey(
        "cbh_core_ws.resources.UserResource", 'created_by')

    class Meta:
        object_class = CustomFieldConfig
        queryset = CustomFieldConfig.objects.select_related(
            "created_by", "data_type",)
        excludes = ("schemaform")
        include_resource_uri = False
        resource_name = 'cbh_custom_field_config'
        authentication = SessionAuthentication()
        authorization = Authorization()
        include_resource_uri = True
        default_format = 'application/json'
        serializer = CustomFieldXLSSerializer()
        # serializer = Serializer()
        filtering = {"id": ALL}
        allowed_methods = ['get', 'post', 'put', 'patch']
        description = {'api_dispatch_detail' : '''
Provides data about a single level of a data form config

data_type: A string to describe what "sort" of data this is (fields will generally be the same as other objects of this data type but that is up to the curator)
project_data_fields:
The fields that are in this particular custom field config:
    Provides information about the data types present in the flexible schema of the datapoint table
    For each field a set of attributes are returned:

    hide_form/schema - an angular schema form element that can be used to hide this column from view
    edit_form /schema - an angular schema form element that can be used to edit this field 

    assuming it is edited as part of a larger data form classification object
    - To change the key of the json schema then change the get_namespace method

    filter_form/schema - an angular schema form element that can be used to hide this filter this field
    
    exclude_form /schema an angular schema form element that can be used to hide this exclude values from this field
   
    sort_form /schema an angular schema form element that can be used to hide this exclude values from this field
   
   Things still to be implemented:

    actions form - would be used for mapping functions etc
    autocomplete urls
        ''',

                       'api_dispatch_list' : '''
Provides data about a single level of a data form config

data_type: A string to describe what "sort" of data this is (fields will generally be the same as other objects of this data type but that is up to the curator)
project_data_fields:
The fields that are in this particular custom field config:
    Provides information about the data types present in the flexible schema of the datapoint table
    For each field a set of attributes are returned:

    hide_form/schema - an angular schema form element that can be used to hide this column from view
    edit_form /schema - an angular schema form element that can be used to edit this field 

    assuming it is edited as part of a larger data form classification object
    - To change the key of the json schema then change the get_namespace method

    filter_form/schema - an angular schema form element that can be used to hide this filter this field
    
    exclude_form /schema an angular schema form element that can be used to hide this exclude values from this field
   
    sort_form /schema an angular schema form element that can be used to hide this exclude values from this field
   
   Things still to be implemented:

    actions form - would be used for mapping functions etc
    autocomplete urls
        '''
                       }


    def get_schema(self, request, **kwargs):
        """
        Returns a serialized form of the schema of the resource.
        Calls ``build_schema`` to generate the data. This method only responds
        to HTTP GET.
        Should return a HttpResponse (200 OK).
        """
        return self.create_response(request, self.build_schema())

    def create_response(self, request, data, response_class=HttpResponse, **response_kwargs):
        """
        Extracts the common "which-format/serialize/return-response" cycle.
        Mostly a useful shortcut/hook.
        """

        desired_format = self.determine_format(request)
        serialized = self.serialize(request, data, desired_format)
        rc = response_class(content=serialized, content_type=build_content_type(
            desired_format), **response_kwargs)

        if(desired_format == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'):
            rc['Content-Disposition'] = 'attachment; filename=project_data_explanation.xlsx'
        return rc


class DataFormConfigResource(ModelResource):
    name = fields.CharField(null=True, blank=True)
    last_level = fields.CharField(null=True, blank=True)
    l0 = fields.ForeignKey("cbh_datastore_ws.resources.SimpleCustomFieldConfigResource",
                           'l0', readonly=True, null=True, blank=False, help_text=None, full=True)
    l1 = fields.ForeignKey("cbh_datastore_ws.resources.SimpleCustomFieldConfigResource",
                           'l1', readonly=True, null=True, blank=False, help_text=None, full=True)
    l2 = fields.ForeignKey("cbh_datastore_ws.resources.SimpleCustomFieldConfigResource",
                           'l2', readonly=True, null=True, blank=False, help_text=None, full=True)
    l3 = fields.ForeignKey("cbh_datastore_ws.resources.SimpleCustomFieldConfigResource",
                           'l3', readonly=True,  null=True, blank=False, help_text=None, full=True)
    l4 = fields.ForeignKey("cbh_datastore_ws.resources.SimpleCustomFieldConfigResource",
                           'l4', readonly=True, null=True, blank=False,  help_text=None, full=True)

    class Meta:
        filtering = {
            "id": ALL
        }
        always_return_data = True
        queryset = DataFormConfig.objects.select_related(

            "l0__created_by",
            "l1__created_by",
            "l2__created_by",
            "l3__created_by",
            "l4__created_by",
            "l0__data_type",
            "l1__data_type",
            "l2__data_type",
            "l3__data_type",
            "l4__data_type",
            "created_by",)
        resource_name = 'cbh_data_form_config'
        authorization = Authorization()
        include_resource_uri = True
        allowed_methods = ['get', 'post', 'put']
        default_format = 'application/json'
        authentication = SessionAuthentication()
        authorization = Authorization()
        description = {'api_dispatch_detail' : '''
Provides data about a all levels of a data form config. 

A data form config's name is built up from its different custom field configs by combining their names and data types in order
<pre>
  _____
l0    |
l1    |
l2    |----- These fields all list the full 
l3    |     information about a level of the data based 
l4____|     upon its custom field configs - see below

</pre>

Only the level that is of importance is shown in full, other levels are left out of the response


data_type: A string to describe what "sort" of data this is (fields will generally be the same as other objects of this data type but that is up to the curator)
==================================================
project_data_fields:
==================================================
The fields that are in this particular custom field config:
    Provides information about the data types present in the flexible schema of the datapoint table
    For each field a set of attributes are returned:

    hide_form/schema - an angular schema form element that can be used to hide this column from view
    edit_form /schema - an angular schema form element that can be used to edit this field 

    assuming it is edited as part of a larger data form classification object
    - To change the key of the json schema then change the get_namespace method

    filter_form/schema - an angular schema form element that can be used to hide this filter this field
    
    exclude_form /schema an angular schema form element that can be used to hide this exclude values from this field
   
    sort_form /schema an angular schema form element that can be used to hide this exclude values from this field
   
   Things still to be implemented:

    actions form - would be used for mapping functions etc
    autocomplete urls
        ''',

                       'api_dispatch_list' : '''
Provides data about a all levels of a data form config. 

A data form config's name is built up from its different custom field configs by combining their names and data types in order
<pre>
  _____
l0    |
l1    |
l2    |----- These fields all list the full 
l3    |     information about a level of the data based 
l4____|     upon its custom field configs - see below

</pre>

Only the level that is of importance is shown in full, other levels are left out of the response


data_type: A string to describe what "sort" of data this is (fields will generally be the same as other objects of this data type but that is up to the curator)
==================================================
project_data_fields:
==================================================
The fields that are in this particular custom field config:
    Provides information about the data types present in the flexible schema of the datapoint table
    For each field a set of attributes are returned:

    hide_form/schema - an angular schema form element that can be used to hide this column from view
    edit_form /schema - an angular schema form element that can be used to edit this field 

    assuming it is edited as part of a larger data form classification object
    - To change the key of the json schema then change the get_namespace method

    filter_form/schema - an angular schema form element that can be used to hide this filter this field
    
    exclude_form /schema an angular schema form element that can be used to hide this exclude values from this field
   
    sort_form /schema an angular schema form element that can be used to hide this exclude values from this field
   
   Things still to be implemented:

    actions form - would be used for mapping functions etc
    autocomplete urls
        '''
                       }
        level = None

    def dehydrate_last_level(self, bundle):
        """Returns the last not null custom field config - useful in checking what level the ui should go to"""
        return bundle.obj.last_level()

    def get_schema(self, request, **kwargs):
        """
        Returns a serialized form of the schema of the resource.
        Calls ``build_schema`` to generate the data. This method only responds
        to HTTP GET.
        Should return a HttpResponse (200 OK).
        """
        # self.method_check(request, allowed=['get'])
        # self.is_authenticated(request)
        # self.throttle_check(request)
        # self.log_throttled_access(request)
        # bundle = self.build_bundle(request=request)
        # self.authorized_read_detail(self.get_object_list(bundle.request), bundle)
        return self.create_response(request, self.build_schema())

    def dehydrate(self, bundle):
        for level in ["l1", "l2", "l3", "l4", "l0"]:
            if bundle.data[level]:
                for field in bundle.data[level].data["project_data_fields"]:
                    for field in bundle.data[level].data["project_data_fields"]:
                        if field.data["handsontable_column"]["data"]:
                            field.data["handsontable_column"]["data"] = field.data[
                                "handsontable_column"]["data"].format(**{"level": level})
                        if field.data["elasticsearch_fieldname"]:
                            field.data["elasticsearch_fieldname"] = field.data[
                                "elasticsearch_fieldname"].format(**{"level": level})
        return bundle


class ProjectWithDataFormResource(CachedResource, ModelResource):
    project_type = fields.ForeignKey(
        "cbh_core_ws.resources.ProjectTypeResource", 'project_type', blank=False, null=False, full=True)
    data_form_configs = fields.ListField(null=True)

    valid_cache_get_keys = ['format', 'limit', 'project_key']

    class Meta:

        excludes = ("schemaform", "custom_field_config")
        queryset = Project.objects.select_related(
            "enabled_forms", "created_by", "project_type")
        authentication = SessionAuthentication()
        allowed_methods = ['get', 'post', 'put']
        resource_name = 'cbh_projects_with_forms'
        authorization = ProjectListAuthorization()
        include_resource_uri = True
        default_format = 'application/json'
        serializer = Serializer()
        filtering = {
            "id": ALL,
            "project_key": ALL_WITH_RELATIONS,
        }
        description =       {'api_dispatch_detail' : '''
A project is the top level item in the system:
project_type : For assay registration project type is not very important - it is just the top level lable
data_form_configs: This dictionary provides the necessary information to build forms from this project.

The enabled forms of the project provide a way of registering routes that the user can take through the system 
but they need to be merged and presented in a way that it is easy to know what options for form data you have.

Parents, grandparents and great grandparents are generated for these objects so that there is an id for every combination
of custom field configs for which data is going to be entered.

The data_form_configs section contains 3 different attributes:

root_data_form_config_uri:
============================

Provides the starting point for this project - this should be a single URI which in turn points to the custom field config used to enter data about the project.

form_lookup
============================
Provides a lookup dictionary from which all of the data form configs needed for a particular project can be looked up by their URIs (here to avoid excess traffic)

permitted_routes_tree
============================
For each data form config URI there are a set of possible data types that can be added as children
        ''',

                             'api_dispatch_list' : '''
A project is the top level item in the system:
project_type : For assay registration project type is not very important - it is just the top level lable


        '''}

    def dehydrate_data_form_configs(self, bundle):
        """ Return a RESTful, DRY list of the data form configs that are allowed for this project"""
        full_dataset = {"form_lookup": {}}
        tree_builder = {}
        root_object = None
        dfcres = DataFormConfigResource()
        resource_uri = dfcres.get_resource_uri()
        qs = DataFormConfigResource.Meta.queryset

        for dfc in bundle.obj.enabled_forms.all():
            root_object = dfc.get_all_ancestor_objects(
                bundle.request, tree_builder=tree_builder, uri_stub=resource_uri)
        filters = set([])
        for key, obj_list in tree_builder.iteritems():
            for i, obj in enumerate(obj_list):
                filters.add(obj.id)
        qs = qs.filter(pk__in=filters)
        by_id = {dpc.id: dpc for dpc in qs}
        for key, obj_list in tree_builder.iteritems():
            for i, obj in enumerate(obj_list):
                objy = by_id[obj.id]
                bun = dfcres.build_bundle(obj=objy, request=bundle.request)
                bun = dfcres.full_dehydrate(bun)

                bun.data["permitted_children"] = []
                tree_builder[key][i] = bun.data["resource_uri"]
                full_dataset["form_lookup"][
                    bun.data["resource_uri"]] = bun.data

        root_obj = tree_builder.pop("root", None)
        full_dataset["permitted_routes_tree"] = tree_builder

        for key, obj_list in tree_builder.iteritems():
            full_dataset["form_lookup"][key]["permitted_children"] = obj_list
            if full_dataset["form_lookup"][key]["last_level"] == "l0":
                full_dataset["form_lookup"][key]["template_data_point_classification"] = {
                    "data_form_config": key,
                    "l0": {
                        "project_data":  {"Title": bundle.obj.name},
                        "custom_field_config": full_dataset["form_lookup"][key]["l0"].data["resource_uri"]
                    },
                    "l0_permitted_projects": [self.get_resource_uri(bundle.obj)]
                }

        real_forms_list = [
            value for key, value in full_dataset["form_lookup"].iteritems()]

        return real_forms_list

    def get_schema(self, request, **kwargs):
        """
        Returns a serialized form of the schema of the resource.
        Calls ``build_schema`` to generate the data. This method only responds
        to HTTP GET.
        Should return a HttpResponse (200 OK).
        """
        # self.method_check(request, allowed=['get'])
        # self.is_authenticated(request)
        # self.throttle_check(request)
        # self.log_throttled_access(request)
        # bundle = self.build_bundle(request=request)
        # self.authorized_read_detail(self.get_object_list(bundle.request), bundle)
        return self.create_response(request, self.build_schema())


class DataPointResource(UserHydrate, ModelResource):
    created_by = fields.ForeignKey(
        "cbh_core_ws.resources.UserResource", 'created_by', null=True, blank=True, default=None,)
    custom_field_config = SimpleResourceURIField(
        "cbh_datastore_ws.resources.SimpleCustomFieldConfigResource", 'custom_field_config_id')
    project_data = CBHDictField(
        attribute='project_data', null=True, blank=False, readonly=False, help_text=None)
    supplementary_data = CBHDictField(
        attribute='supplementary_data', null=True, blank=False, readonly=False, help_text=None)

    class Meta:

        always_return_data = False
        queryset = DataPoint.objects.all()
        resource_name = 'cbh_datapoints'
        authorization = Authorization()
        include_resource_uri = True
        allowed_methods = ['get', 'post', 'put']
        authentication = SessionAuthentication()
        default_format = 'application/json'
        serializer = Serializer()
        description = {"api_dispatch_detail": """
Data point is the entitity through which all data is stored on the system but this resource is not used adding data because the data point classification must be known in order to add a datapoint.
It has the following fields:
    created_by: the user that added this data
    custom_field_config: The URI of the custom field config that can be used to parse, display and edit this data
    
    project_data: The dictionary that contains the data - this should match the fields provided in the custom field schema but is NOT CURRENT VALIDATED on the backend
    supplementary data: A space to store other things about this item
""",
                       "api_dispatch_list": """
Data point is the entitity through which all data is stored on the system but this resource is not used adding data because the data point classification must be known in order to add a datapoint.
It has the following fields:
    created_by: the user that added this data
    custom_field_config: The URI of the custom field config that can be used to parse, display and edit this data
    
    project_data: The dictionary that contains the data - this should match the fields provided in the custom field schema but is NOT CURRENT VALIDATED on the backend
    supplementary data: A space to store other things about this item
"""}

    def hydrate_project_data(self, bundle):
        bundle.obj.project_data = {key: unicode(value) for key, value in bundle.data["project_data"].items()}
        return bundle



    def get_schema(self, request, **kwargs):
        """
        Returns a serialized form of the schema of the resource.
        Calls ``build_schema`` to generate the data. This method only responds
        to HTTP GET.
        Should return a HttpResponse (200 OK).
        """
        # self.method_check(request, allowed=['get'])
        # self.is_authenticated(request)
        # self.throttle_check(request)
        # self.log_throttled_access(request)
        # bundle = self.build_bundle(request=request)
        # self.authorized_read_detail(self.get_object_list(bundle.request), bundle)
        return self.create_response(request, self.build_schema())


class MyForeignKey(fields.ForeignKey):

    def should_full_dehydrate(self, bundle, for_list):
        return bundle.request.GET.get("full", None)


class DataPointClassificationResource(UserHydrate, ModelResource):

    '''Returns individual rows in the object graph - note that the rows returned are denormalized data points '''
    created_by = fields.ForeignKey(
        "cbh_core_ws.resources.UserResource", 'created_by', null=True, blank=True,  default=None)
    data_form_config = SimpleResourceURIField(
        "cbh_datastore_ws.resources.DataFormConfigResource", 'data_form_config_id',)
    l0_permitted_projects = fields.ToManyField(
        "cbh_datastore_ws.resources.ProjectWithDataFormResource", attribute="l0_permitted_projects", full=False)
    level_from = fields.CharField(null=True, blank=False, default=None)
    next_level = fields.CharField(null=True, blank=False, default=None)
    l0 = MyForeignKey("cbh_datastore_ws.resources.DataPointResource",
                      'l0', null=True, blank=False, default=None, )
    l1 = MyForeignKey("cbh_datastore_ws.resources.DataPointResource",
                      'l1', null=True, blank=False, default=None,)
    l2 = MyForeignKey("cbh_datastore_ws.resources.DataPointResource",
                      'l2', null=True, blank=False, default=None, )
    l3 = MyForeignKey("cbh_datastore_ws.resources.DataPointResource",
                      'l3', null=True, blank=False, default=None, )
    l4 = MyForeignKey("cbh_datastore_ws.resources.DataPointResource",
                      'l4', null=True, blank=False, default=None,)
    parent_id = fields.IntegerField(attribute="parent_id", null=True)

    class Meta:
        filtering = {
            "data_form_config": ALL_WITH_RELATIONS,
            "l0_permitted_projects": ALL_WITH_RELATIONS,
            "l0": ALL_WITH_RELATIONS,
            "l1": ALL_WITH_RELATIONS,
            "l2": ALL_WITH_RELATIONS,
            "l3": ALL_WITH_RELATIONS,
            "l4": ALL_WITH_RELATIONS,
        }
        # Must be true so that the hook for elasticsearch indexing works
        always_return_data = True
        queryset = DataPointClassification.objects.all().select_related("created_by",
                                                                        "l0__created_by",
                                                                        "l1__created_by",
                                                                        "l2__created_by",
                                                                        "l3__created_by",
                                                                        "l4__created_by",

                                                                        "l0__custom_field_config__pinned_custom_field",
                                                                        "l1__custom_field_config__pinned_custom_field",
                                                                        "l2__custom_field_config__pinned_custom_field",
                                                                        "l3__custom_field_config__pinned_custom_field",
                                                                        "l4__custom_field_config__pinned_custom_field",

                                                                        "l0__custom_field_config__data_type",
                                                                        "l1__custom_field_config__data_type",
                                                                        "l2__custom_field_config__data_type",
                                                                        "l3__custom_field_config__data_type",
                                                                        "l4__custom_field_config__data_type",



                                                                        "l0_permitted_projects",
                                                                        "data_form_config__l0__pinned_custom_field",
                                                                        "data_form_config__l1__pinned_custom_field",
                                                                        "data_form_config__l2__pinned_custom_field",
                                                                        "data_form_config__l3__pinned_custom_field",
                                                                        "data_form_config__l4__pinned_custom_field",
                                                                        "data_form_config__l0__created_by",
                                                                        "data_form_config__l1__created_by",
                                                                        "data_form_config__l2__created_by",
                                                                        "data_form_config__l3__created_by",
                                                                        "data_form_config__l4__created_by",

                                                                        "data_form_config__l0__data_type",
                                                                        "data_form_config__l1__data_type",
                                                                        "data_form_config__l2__data_type",
                                                                        "data_form_config__l3__data_type",
                                                                        "data_form_config__l4__data_type",

                                                                        )
        resource_name = 'cbh_datapoint_classifications'
        #authorization = Authorization()
        default_format = 'application/json'
        include_resource_uri = True
        allowed_methods = ['get', 'post', 'patch']
        default_format = 'application/json'
        serializer = DataPointClassificationSerializer()
        authentication = SessionAuthentication()
        authorization = DataClassificationProjectAuthorization()
        required_fields = {
            "l0_permitted_projects": "Must contain a list of URIs for the projects that the user wants to add this datapoint and all of its children to.",
            "data_form_config": "Must contain the URI of the data form config which was used to create this object and l0,1,2,3 and 4"
        }
        description = {"api_dispatch_detail": """
Data Point Classification:
This is the index of all of the data points (nodes of data) on the system. Although the data is in the form of a tree, it is stored in a flat format
Each form that is associated with a project will have its own tree of data within that project
If the tree of data produced by a form looks like this then 
<pre>

        l0 project_X 
        ├── l1 subproject_A
        │   ├── l2 assay_A
        │   │   ├── l3 bioactivity_V
        │   │   ├── l3 bioactivity_W
        │   │   └── l3 bioactivity_X
        │   └── l2 assay_B
        │       └── l4 bioactivity_Y
        └── l1 subproject_B
</pre>
For each leaf node in the tree there will be one data point classification object
<pre>
        l0 project_X                        
        ├── l1 subproject_A
        │   ├── l2 assay_A
        │   │   ├── l3 bioactivity_V
        │   │   ├── l3 bioactivity_W
        │   │   └── l3 bioactivity_X
        │   └── l2 assay_B
        │       └── l4 bioactivity_Y
        └── l1 subproject_B
</pre>
<pre>
{"l0" : "uri for project_X's data point"}
{"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" }
{"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_A" }
{"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_A" , "l3": "bioactivity_V"}
{"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_A" , "l3": "bioactivity_W"}
{"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_A" , "l3": "bioactivity_X"}
{"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_B" }
{"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_A" , "l3": "bioactivity_Y"}
{"l0" : "uri for project_X's data point", "l1": "uri for subproject_B" }
</pre>

There is a lot of repetition in the output of this API hence the user requests the datapoints separately by calling the list ids endpoint

In order to request data for one project and one form, the request will be:

dev/data_point_classifications/?l0_permitted_projects__id=1&data_form_config__id=1

But this will return ALL of the classification objects i.e. all levels of the tree

If you just want level 0 - the top of the tree do:

dev/data_point_classifications/?l0_permitted_projects__id=1&data_form_config__id=1?l1__id=1&l2__id=2l3__id=1&l4__id=4

Now, if you want to filter for a specific l0__id then add that to the filter

dev/data_point_classifications/?l0_permitted_projects__id=1&data_form_config__id=1?l0__id=12l1__id=1&l2__id=2l3__id=1&l4__id=4


""",
                       "api_dispatch_list": """

This is the index of all of the data points (nodes of data) on the system. Although the data is in the form of a tree, it is stored in a flat format
Each form that is associated with a project will have its own tree of data within that project
If the tree of data produced by a form looks like this then 
<pre>
            l0 project_X   
            ├── l1 subproject_A
            │   ├── l2 assay_A
            │   │   ├── l3 bioactivity_V
            │   │   ├── l3 bioactivity_W
            │   │   └── l3 bioactivity_X
            │   └── l2 assay_B
            │       └── l4 bioactivity_Y
            └── l1 subproject_B
</pre>

For each leaf node in the tree there will be one data point classification object
<pre>
    l0 project_X                        
    ├── l1 subproject_A
    │   ├── l2 assay_A
    │   │   ├── l3 bioactivity_V
    │   │   ├── l3 bioactivity_W
    │   │   └── l3 bioactivity_X
    │   └── l2 assay_B
    │       └── l4 bioactivity_Y
    └── l1 subproject_B

    {"l0" : "uri for project_X's data point"}
    {"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" }
    {"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_A" }
    {"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_A" , "l3": "bioactivity_V"}
    {"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_A" , "l3": "bioactivity_W"}
    {"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_A" , "l3": "bioactivity_X"}
    {"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_B" }
    {"l0" : "uri for project_X's data point", "l1": "uri for subproject_A" , "l2": "uri for assay_A" , "l3": "bioactivity_Y"}
    {"l0" : "uri for project_X's data point", "l1": "uri for subproject_B" }
</pre>

There is a lot of repetition in the output of this API hence the user requests the datapoints separately by calling the list ids endpoint

In order to request data for one project and one form, the request will be:

dev/data_point_classifications/?l0_permitted_projects__id=1&data_form_config__id=1

But this will return ALL of the classification objects i.e. all levels of the tree

If you just want level 0 - the top of the tree do:

dev/data_point_classifications/?l0_permitted_projects__id=1&data_form_config__id=1?l1__id=1&l2__id=2l3__id=1&l4__id=4

Now, if you want to filter for a specific l0__id then add that to the filter

dev/data_point_classifications/?l0_permitted_projects__id=1&data_form_config__id=1?l0__id=12l1__id=1&l2__id=2l3__id=1&l4__id=4



""",

                       "api_post_list" : """
Read the docs for the get API before attempting to post

Create a set of custom field configs and a data form config and a project
Get the URIs for each of these based on their

By posting to this API you create a datapoint classification object.
To add an entirely new l0 object format needs to look like this:
<pre>
{
    "data_form_config":"/dev/datastore/cbh_data_form_config/5", 
    "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/9"] }
    "l0": {"project_data":{"fields": "based", "on": "the", "custom": "field","config": "go here"} , 
    "custom_field_config" : "/dev/datastore/cbh_custom_field_config/744"}
}
</pre>
OR is could look like this:
<pre>
{
    "data_form_config":{"pk":5}, 
    "l0_permitted_projects": [{"pk":5}] }
    "l0": {"project_data":{"fields": "based", "on": "the", "custom": "field","config": "go here"} , 
    "custom_field_config" : {"pk": 115}
}
</pre>


To add an "l1" to the existing l0 the format should look like this:
<pre>

{
    "data_form_config":"/dev/datastore/cbh_data_form_config/4", 
    "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] }
    "l0": "cbh_datapoints/10" ,
    "l1": {"project_data":{"fields": "based", "on": "the", "custom": "field","config": "go here"} , 
    "custom_field_config" : ""/dev/datastore/cbh_custom_field_configs/45"}
}
</pre>
Once that "l1" object has been added ensure it has an id in the UI

Then, if the whole object is patched back in this case then only l1 will be updated
If there is NO ID or URI or pk in the l1 object then a new leaf will be created
<pre>
{
    "id": 453,
    "data_form_config":"/dev/datastore/cbh_data_form_config/4", 
    "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] }
    "l0": "cbh_datapoints/10" ,
    "l1": {"id":999, project_data":{"fields": "deifferent", "on": "values", "custom": "this time","config": "go here"} , 
    "custom_field_config" : ""/dev/datastore/cbh_custom_field_configs/45"}
}
</pre>
"""
                       ,



                       }

    def obj_create(self, bundle, **kwargs):
        """
        A ORM-specific implementation of ``obj_create``.
        """
        bundle.obj = self._meta.object_class()
        for key, value in kwargs.items():
            setattr(bundle.obj, key, value)
        t = time.time()
        bundle = self.full_hydrate(bundle)
        return self.save(bundle,)

    def get_object_list(self, request):
        return super(DataPointClassificationResource, self).get_object_list(request)

    def apply_filters(self, request, applicable_filters):
        pids = self._meta.authorization.project_ids(request)
        dataset = self.get_object_list(request).filter(
            **applicable_filters).filter(l0_permitted_projects__id__in=set(pids))
        return dataset.order_by("-modified")



    def dehydrate_level_from(self, bundle):
        return bundle.obj.level_from()

    def dehydrate_next_level(self, bundle):
        next_level = ""
        if bundle.obj.l4_id != 1:
            return "l5"
        if bundle.obj.l3_id != 1:
            return "l4"
        if bundle.obj.l2_id != 1:
            return "l3"
        if bundle.obj.l1_id != 1:
            return "l2"
        if bundle.obj.l0_id != 1:
            return "l1"
        return next_level

    def save(self, bundle, skip_errors=False):
        mt = time.time()
        # if bundle.via_uri:
        #     return bundle
        self.is_valid(bundle)

        if bundle.errors and not skip_errors:
            raise ImmediateHttpResponse(
                response=self.error_response(bundle.request, bundle.errors))
        m2m_bundle = self.hydrate_m2m(bundle)
        # Check if they're authorized.

        if bundle.obj.pk:
            self.authorized_update_detail(
                self.get_object_list(bundle.request), bundle)
        else:
            self.authorized_create_detail(
                self.get_object_list(bundle.request), bundle)
        # Save FKs just in case.
        self.save_related(bundle)
        # Save the main object.
        obj_id = self.create_identifier(bundle.obj)

        if obj_id not in bundle.objects_saved or bundle.obj._state.adding:
           
            bundle.obj.save()
            bundle.objects_saved.add(obj_id)
       
        self.save_m2m(m2m_bundle)
        return bundle

    def create_response(self, request, data, response_class=HttpResponse, **response_kwargs):
        """
        Extracts the common "which-format/serialize/return-response" cycle.
        Mostly a useful shortcut/hook.
        """
        desired_format = self.determine_format(request)
        if request.GET.get("standardised", None):
            data.data["standardised"] = True
        
        if response_class == http.HttpCreated or response_class == http.HttpAccepted:
            request.GET = request.GET.copy()
            request.GET["full"] = True
            serialized = self.serialize(request, data, desired_format)
            # There has been a new object created - we must now index it
            # elasticsearch_client.index_datapoint_classification(serialized)
            filters = data.obj.all_child_generations_filter_dict()
            index_filter_dict(filters)
        else:
            serialized = self.serialize(request, data, desired_format)
        #
        #     #Standardise the output data
        return response_class(content=serialized, content_type=build_content_type(desired_format), **response_kwargs)

    def save_related(self, bundle):
        """
        Handles the saving of related non-M2M data.
        Calling assigning ``child.parent = parent`` & then calling
        ``Child.save`` isn't good enough to make sure the ``parent``
        is saved.
        To get around this, we go through all our related fields &
        call ``save`` on them if they have related, non-M2M data.
        M2M data is handled by the ``ModelResource.save_m2m`` method.
        """
        for field_name, field_object in self.fields.items():
            if not getattr(field_object, 'is_related', False):
                continue

            if getattr(field_object, 'is_m2m', False):
                continue

            if not field_object.attribute:
                continue

            if field_object.readonly:
                continue

            if field_object.blank and not field_name in bundle.data:
                continue

            # Get the object.
            try:
                related_obj = getattr(bundle.obj, field_object.attribute)
            except ObjectDoesNotExist:
                # Django 1.8: unset related objects default to None, no error
                related_obj = None

            # We didn't get it, so maybe we created it but haven't saved itfield.obj.save()
            if related_obj is None:
                related_obj = bundle.related_objects_to_save.get(
                    field_object.attribute, None)

            if field_object.related_name:
                if not self.get_bundle_detail_data(bundle):
                    bundle.obj.save()

                setattr(related_obj, field_object.related_name, bundle.obj)

            related_resource = field_object.get_related_resource(related_obj)

            # Before we build the bundle & try saving it, let's make sure we
            # haven't already saved it.
            if related_obj:
                obj_id = self.create_identifier(related_obj)

                if obj_id in bundle.objects_saved:
                    # It's already been saved. We're done here.
                    continue
                if related_obj.__class__.__name__ == "DataPoint":
                    if obj_id == "cbh_datastore_model.datapoint.1":
                        if related_obj.project_data != {}:
                            raise ImmediateHttpResponse(HttpConflict(
                                "You are trying to update the default datapoint, this is not allowed, remove the id from the default datapoint before updating")
                            )

            if bundle.data.get(field_name) and hasattr(bundle.data[field_name], 'keys'):
                # Only build & save if there's data, not just a URI.
                related_bundle = related_resource.build_bundle(
                    obj=related_obj,
                    data=bundle.data.get(field_name),
                    request=bundle.request,
                    objects_saved=bundle.objects_saved
                )
                related_resource.full_hydrate(related_bundle)
                t = time.time()
                related_resource.save(related_bundle)

                related_obj = related_bundle.obj

            if related_obj:
                setattr(bundle.obj, field_object.attribute, related_obj)

    def save_m2m(self, bundle):
        for field_name, field_object in self.fields.items():
            if not getattr(field_object, 'is_m2m', False):
                continue

            if not field_object.attribute:
                continue

            for field in bundle.data[field_name]:
                kwargs = {'data_point_classification_id': bundle.obj.id,
                          'project': field.obj}

                try:
                    DataPointClassificationPermission.objects.get_or_create(
                        **kwargs)
                except IntegrityError:
                    continue

    def get_schema(self, request, **kwargs):
        """
        Returns a serialized form of the schema of the resource.
        Calls ``build_schema`` to generate the data. This method only responds
        to HTTP GET.
        Should return a HttpResponse (200 OK).
        """
        # self.method_check(request, allowed=['get'])
        # self.is_authenticated(request)
        # self.throttle_check(request)
        # self.log_throttled_access(request)
        # bundle = self.build_bundle(request=request)
        # self.authorized_read_detail(self.get_object_list(bundle.request), bundle)
        return self.create_response(request, self.build_schema())

    ###
    # DRAFT STUFF HERE
    ###
    import time
    current_milli_time = lambda: int(round(time.time() * 1000))

    #using this to accept autosave/draft save requests
    #and also return a list of saved drafts if required
    #and also return a single cached draft if reverting to a previous version
    class dict2obj(object):
        """
        Convert dictionary to object
        @source http://stackoverflow.com/a/1305561/383912
        """
        def __init__(self, d):
            self.__dict__['d'] = d

        def __getattr__(self, key):
            value = self.__dict__['d'][key]
            if type(value) == type({}):
                return dict2obj(value)

            return value

    def prepend_urls(self):
        return [
            url(r"^(?P<resource_name>%s)/save_draft/$" % self._meta.resource_name,
                self.wrap_view('save_draft'), name="api_save_draft"),
            url(r"^(?P<resource_name>%s)/get_draft_list/$" % self._meta.resource_name,
                self.wrap_view('get_draft_list'), name="api_get_draft_list"),
            url(r"^(?P<resource_name>%s)/get_draft/$" % self._meta.resource_name,
                self.wrap_view('get_draft'), name="api_get_draft"),

        ]

    def save_draft(self, request, **kwargs):
        #take the json data supplied and save to the session
        #use the timestamp or current millis as a key - may be able to generate this in the front end
        #print(request.GET)

        if request.GET.get('content'):
            #does drafts exist? if not, create it
            drafts_obj = request.session.get('drafts', [])
            if drafts_obj.length > 0:
                request.session['drafts'] = []

            draft_obj = {}
            draft_obj['draft_key'] = current_milli_time()
            draft_obj['content'] = request.GET.get('content')
        
        request.session[drafts].append(draft_obj)            

        return HttpResponse(content=draft_key, content_type=self._meta.default_format)

    def get_draft_list(self, request, **kwargs):
        #get all of the drafts within the current session, if any
        return_item = []
        if request.session[drafts]:
            return_item = request.session[drafts]
        
        return HttpResponse(content=return_item, content_type=self._meta.default_format)

    def get_draft(self, request, **kwargs):
        #get the draft matching the timestamp based key (or other key)
        if request.GET.get('draft_key'):
            drafts = request.session[drafts]
            for draft in drafts:
                if draft['draft_key'] == request.GET.get('draft_key'):
                    return HttpResponse(content=draft['content'], content_type=self._meta.default_format)
            #no match? send empty response
            return HttpResponse(content={}, content_type=self._meta.default_format)
        else:
            return HttpResponse(content={}, content_type=self._meta.default_format)



def chunks(l, n):
    """Yield successive n-sized chunks from l."""
    for i in xrange(0, len(l), n):
        yield l[i:i+n]


def reindex_datapoint_classifications():
    offset = 0
    aggs = DataPointClassification.objects.aggregate(Max("id"), Min("id"))

    res = DataPointClassificationResource()
    req = HttpRequest()
    req.GET = req.GET.copy()
    req.GET["full"] = True
    try:
        chunked = chunks(range(aggs["id__min"], aggs["id__max"]), 100)
        for chunk in chunked:

            index_filter_dict({"id__in": chunk})
    except TypeError:
        # Nonetype found therefore dpcs are empty
        elasticsearch_client.index_datapoint_classification(
            '{"objects" :[]}', refresh=True)

    time.sleep(1)


@job
def index_filter_dict(filter_dict, dpcs=None):
    """When a datapointclassification is updated we know that the front end only targets the 
    level_from datapoint. The specific datapoint will be updated in realtime however 
    we also need to update any references to that datapoint in its children. To find all children, we simply 
    search for all of the level datapoint ids that are not default using this general queryset function
    """
    res = DataPointClassificationResource()
    request = HttpRequest()
    request.GET = request.GET.copy()
    request.GET["full"] = True
    request.GET["standardised"] = True

    bundle = res.build_bundle(request=request)
    dpcs = res.Meta.queryset.filter(**filter_dict)
    dfc_ids = set([dpc.data_form_config_id for dpc in dpcs])
    another_req = HttpRequest()
    another_req.GET = another_req.GET.copy()
    another_req.GET["id__in"] = ",".join([str(id) for id in list(dfc_ids)])
    dfcr = DataFormConfigResource()
    forms = dfcr.get_list(another_req)
    dataset = json.loads(forms.content)

    bundle.data["objects"] = [
        res.full_dehydrate(res.build_bundle(obj=dpc, request=request)) for dpc in dpcs]

    bundle.data["forms"] = {frm["resource_uri"]: frm for frm in dataset["objects"]}
    resp = res.create_response(request, bundle)

    elasticsearch_client.index_datapoint_classification(
        resp.content, refresh=True)


def test_fields(bundles_lists, objects):
    for dictionary in objects:

        for bundle_list in bundles_lists:
            value = dictionary["project_data"].get(bundle_list[0].data["elasticsearch_fieldname"], "")
            is_valid = bundle_list[1].obj.validate_field(value)
            if not is_valid:
                bundle_list[0].data["unmappable_rows"].append(dictionary["id"])
    for bundle_list in bundles_lists:
        if len(bundle_list[0].data["unmappable_rows"]) > 0:
            bundle_list[0].data["attachment_field_unmappable_to"] = copy(bundle_list[0].data["attachment_field_mapped_to"])
            bundle_list[0].data["attachment_field_mapped_to"] = None
            bundle_list[0].obj.attachment_field_mapped_to_id = None



class BaseAttachmentResource(ModelResource):
    data_point_classification = fields.ForeignKey(
        "cbh_datastore_ws.resources.DataPointClassificationResource", attribute="data_point_classification", full=True)
    flowfile = fields.ForeignKey(
        "cbh_datastore_ws.resources.FlowFileResource", attribute="flowfile")
    attachment_custom_field_config = fields.ForeignKey(
        SimpleCustomFieldConfigResource, readonly=True, attribute="attachment_custom_field_config", full=True)
    created_by = fields.ForeignKey(UserResource, "created_by")

    class Meta:
        queryset = Attachment.objects.all().select_related(
            "chosen_data_form_config__l0__pinned_custom_field",
            "chosen_data_form_config__l1__pinned_custom_field",
            "chosen_data_form_config__l2__pinned_custom_field",
            "chosen_data_form_config__l3__pinned_custom_field",
            "chosen_data_form_config__l4__pinned_custom_field",
            "chosen_data_form_config__l0__created_by",
            "chosen_data_form_config__l1__created_by",
            "chosen_data_form_config__l2__created_by",
            "chosen_data_form_config__l3__created_by",
            "chosen_data_form_config__l4__created_by",
            "chosen_data_form_config__l0__data_type",
            "chosen_data_form_config__l1__data_type",
            "chosen_data_form_config__l2__data_type",
            "chosen_data_form_config__l3__data_type",
            "chosen_data_form_config__l4__data_type",
            "chosen_data_form_config__created_by",
            "created_by",
            "flowfile",
            "attachment_custom_field_config__created_by",
            "attachment_custom_field_config__data_type",
            "attachment_custom_field_config__pinned_custom_field",
        )
        always_return_data = True  # required to add the elasticsearch data
        resource_name = 'cbh_base_attachments'
        default_format = 'application/json'
        include_resource_uri = True
        allowed_methods = ['post', 'get']
        default_format = 'application/json'
        serializer = Serializer()
        authentication = SessionAuthentication()
        #need to replace this authorization with a custom one to check user can access the DPC
        authorization = Authorization()

    def prepend_urls(self):
        return [
            # url(r"^(?P<resource_name>%s)/save_temporary_data$" % self._meta.resource_name,
            #     self.wrap_view('post_save_temp_data'), name="save_temporary_data"),
            # url(r"^(?P<resource_name>%s)__(?P<pk>\d[\d]*)/_search$" % self._meta.resource_name,
            #     self.wrap_view('search_temp_data'), name="search_temp_data"),
        ]

    #this is to render
    def get_detail(self, request, **kwargs):
        """
        Returns a single serialized resource.
        Calls ``cached_obj_get/obj_get`` to provide the data, then handles that result
        set and serializes it.
        Should return a HttpResponse (200 OK).
        """
        basic_bundle = self.build_bundle(request=request)

        try:
            obj = self.cached_obj_get(bundle=basic_bundle, **self.remove_api_resource_names(kwargs))
        except ObjectDoesNotExist:
            return http.HttpNotFound()
        except MultipleObjectsReturned:
            return http.HttpMultipleChoices("More than one resource is found at this URI.")

        bundle = self.build_bundle(obj=obj, request=request)
        bundle = self.full_dehydrate(bundle)
        bundle = self.alter_detail_data_to_serialize(request, bundle)

        #return our response here
        #get extension from the FlowFile object
        #match this to a dictionary of mimetypes with extensions
        fb = open(flowfile.file).read()
        return HttpResponse(fb, mimetype="image/png")


        #return self.create_response(request, bundle)


    # #override create_response
    # def create_response(self, request, data, response_class=HttpResponse, **response_kwargs):
    #     """
    #     Extracts the common "which-format/serialize/return-response" cycle.
    #     Mostly a useful shortcut/hook.
    #     """
    #     #if mime type is specified in kwargs

    #     #if mime type not specified in url, do default
    #     desired_format = self.determine_format(request)
    #     serialized = self.serialize(request, data, desired_format)
    #     return response_class(content=serialized, content_type=build_content_type(desired_format), **response_kwargs)



class AttachmentResource(UserHydrate, ModelResource):
    data_point_classification = fields.ForeignKey(
        "cbh_datastore_ws.resources.DataPointClassificationResource", attribute="data_point_classification", full=True)
    flowfile = fields.ForeignKey(
        "cbh_datastore_ws.resources.FlowFileResource", attribute="flowfile")
    attachment_custom_field_config = fields.ForeignKey(
        SimpleCustomFieldConfigResource, readonly=True, attribute="attachment_custom_field_config", full=True)
    chosen_data_form_config = fields.ForeignKey(
        DataFormConfigResource, attribute="chosen_data_form_config", full=True)
    created_by = fields.ForeignKey(UserResource, "created_by")

    class Meta:
        queryset = Attachment.objects.all().select_related(
            "chosen_data_form_config__l0__pinned_custom_field",
            "chosen_data_form_config__l1__pinned_custom_field",
            "chosen_data_form_config__l2__pinned_custom_field",
            "chosen_data_form_config__l3__pinned_custom_field",
            "chosen_data_form_config__l4__pinned_custom_field",
            "chosen_data_form_config__l0__created_by",
            "chosen_data_form_config__l1__created_by",
            "chosen_data_form_config__l2__created_by",
            "chosen_data_form_config__l3__created_by",
            "chosen_data_form_config__l4__created_by",
            "chosen_data_form_config__l0__data_type",
            "chosen_data_form_config__l1__data_type",
            "chosen_data_form_config__l2__data_type",
            "chosen_data_form_config__l3__data_type",
            "chosen_data_form_config__l4__data_type",
            "chosen_data_form_config__created_by",
            "created_by",
            "flowfile",
            "attachment_custom_field_config__created_by",
            "attachment_custom_field_config__data_type",
            "attachment_custom_field_config__pinned_custom_field",
        )
        always_return_data = True  # required to add the elasticsearch data
        resource_name = 'cbh_attachments'
        default_format = 'application/json'
        include_resource_uri = True
        allowed_methods = ['post', 'get']
        default_format = 'application/json'
        serializer = Serializer()
        authentication = SessionAuthentication()
        authorization = Authorization()

    def prepend_urls(self):
        return [
            url(r"^(?P<resource_name>%s)/save_temporary_data$" % self._meta.resource_name,
                self.wrap_view('post_save_temp_data'), name="save_temporary_data"),
            url(r"^(?P<resource_name>%s)__(?P<pk>\d[\d]*)/_search$" % self._meta.resource_name,
                self.wrap_view('search_temp_data'), name="search_temp_data"),
        ]




    def hydrate(self, bundle):
        bundle.obj.flowfile = self.flowfile.hydrate(bundle).obj
        flowfile = bundle.obj.flowfile
        if bundle.obj.attachment_custom_field_config_id is None:
            data, names, data_types, widths = get_sheet(
                flowfile.path, bundle.data["sheet_name"])
            name = "%s>>%d>>%s>>%s" % (bundle.obj.created, flowfile.id, flowfile.path, bundle.data["sheet_name"])
            bundle.obj.attachment_custom_field_config = CustomFieldConfig.objects.from_schema_lists(data, 
                                                                                                    names, 
                                                                                                    data_types,
                                                                                                    widths,
                                                                                                     name, 
                                                                                                     bundle.request.user)
            #Add 2 to the index number in order to make the row number in Excels
            tempobjects = [{
                "id": index +2,
                "attachment_data": {"project_data": item, "created_by_id": bundle.obj.created_by_id,"id": index +2, },
                "created_by_id": bundle.obj.created_by_id,
            } for index, item in enumerate(data)]
            bundle.data["tempobjects"] = tempobjects
            bundle.obj.number_of_rows = len(tempobjects)
        return bundle

    def prepare_newly_saved_data(self, bundle):
        """Get the related fields and make them into a list of possibilities"""

        last_level = bundle.data["chosen_data_form_config"].data["last_level"]
        fields_being_added_to = bundle.data["chosen_data_form_config"].data[
            last_level].data["project_data_fields"]
        bundle.data["chosen_data_form_config"] = bundle.data["chosen_data_form_config"].data["resource_uri"]
        bundle.data["titleMap"] = [{"value": None, "name": "Pick a field"}]
        bundle.data["titleMap"] += [{
                          "value": choice_of_field.data["resource_uri"],
                          "name": choice_of_field.data["name"],
                          "required": choice_of_field.data["required"]
                        } for choice_of_field in fields_being_added_to]
        
        already_mapped = {}
        fuzzy_choices = {}
        for field in  bundle.data["attachment_custom_field_config"].data["project_data_fields"]:
            field.data["unmappable_rows"] = []
            field.data["mapped_to_form"] = {
                  "key": "attachment_field_mapped_to",
                  "type": "select"
                }

            
            default_set = False
            field.data["mapped_to_schema"] = {"properties" : {"type": "string", }, }

            
            for index, choice_of_field in enumerate(fields_being_added_to):
                # field.data["mapped_to_schema"]["properties"]["enum"].append(
                #     choice_of_field.data["resource_uri"])
                
                if choice_of_field.data["name"].strip() == field.data["name"].strip():
                    #Exact match case
                    if not choice_of_field.obj.id in  already_mapped:
                        fuzzy_choices[choice_of_field.data["resource_uri"]] = (field, choice_of_field, True)
                        already_mapped[choice_of_field.obj.id] = 100
                        

        
        for field in  bundle.data["attachment_custom_field_config"].data["project_data_fields"]: 
            for index, choice_of_field in enumerate(fields_being_added_to):
                fuzz_ratio =  fuzz.ratio(choice_of_field.data["name"].lower(),field.data["name"].lower())
                if  fuzz_ratio > already_mapped.get(choice_of_field.obj.id, 85):
                    #Fuzzy match case - better fuzzy match than any other assigned to this field
                    #We priorities fields earlier in the column headers but replace them if there is a better fuzzy match later
                    fuzzy_choices[choice_of_field.data["resource_uri"]] = (field, choice_of_field, False)
                    already_mapped[choice_of_field.obj.id] = fuzz_ratio
                    
        for uri, fieldbits in fuzzy_choices.items():
            fieldbits[0].data["attachment_field_mapped_to"] = uri
            fieldbits[0].obj.attachment_field_mapped_to_id = fieldbits[1].data["id"]
            fieldbits[0].obj.save()
            fieldbits[0].data["mapped_to_schema"]["exact_match"] = fieldbits[2]
        choices = [(fieldbits[0], fieldbits[1]) for key, fieldbits in fuzzy_choices.items()]
        test_fields(choices, [dictionary["attachment_data"] for dictionary in bundle.data["tempobjects"]])
        for uri, fieldbits in fuzzy_choices.items():
            fieldbits[0].obj.save()
        return bundle


    def retrieve_temp_data(self,  request, attachment_json):
        results_to_find = attachment_json["number_of_rows"]
        frompoint = 0
        increment = 1000
        
        while results_to_find > 0:
            request.GET = request.GET.copy()
            request.GET["from"] = frompoint
            request.GET["size"] = increment
            request.GET["index_name"] = elasticsearch_client.get_attachment_index_name(
                int(attachment_json["id"]))
            request.GET["sort"] = '_id:desc'
            qr = QueryResource()
            resp = qr.alter_detail_data_to_serialize(
                request, self.build_bundle())

            last_level = attachment_json[
                "chosen_data_form_config"]["last_level"]
            for hit in resp.data["hits"]["hits"]:
            # hits_to_use = resp.data["hits"]["hits"]
            # for hit in sorted(hits_to_use, key=hits_to_use._source.id, reverse=True):
                yield hit["_source"]["attachment_data"]
                
            results_to_find = results_to_find - increment


    def search_temp_data(self, request, **kwargs):
        attachment_pk = kwargs.get("pk", None)
        if attachment_pk:
            request.GET = request.GET.copy()
            request.GET["index_name"] = elasticsearch_client.get_attachment_index_name(
                int(attachment_pk))
            qr = QueryResource()
            return qr.post_list(request)
        raise BadRequest("no pk specified")

    def post_save_temp_data(self, request, **kwargs):
        #attachment_pk = kwargs.get("pk",None)
        attachment_pk = request.GET.get("sheetId", None)
        request.GET = request.GET.copy()
        request.GET["empty"] = True
        if attachment_pk:
            attachment_json = json.loads(
                self.get_detail(request, pk=attachment_pk).content)
            dpc_obj_template = DataPointClassification.objects.get(
                pk=attachment_json["data_point_classification"]["id"])
            last_level = attachment_json[
                "chosen_data_form_config"]["last_level"]
            projects = [
                proj for proj in dpc_obj_template.l0_permitted_projects.all()
                ]
            hits = self.retrieve_temp_data(request, attachment_json)
            ids = []
            field_mappings = get_field_mappings(attachment_json["attachment_custom_field_config"]["project_data_fields"]
                ,attachment_json["chosen_data_form_config"][last_level]["project_data_fields"])
            for hitsource in hits:
                defaults = {}
                defaults["project_data"] = { mapping[1]: hitsource["project_data"].get(mapping[0], "") for mapping in field_mappings }
                defaults["created_by_id"] = request.user.pk
                dp = DataPoint(**defaults)
                dp.custom_field_config_id = attachment_json[
                    "chosen_data_form_config"][last_level]["id"]
                dp.save()
                dpc_obj_template.created_by_id = request.user.pk
                dpc_obj_template.id = None
                dpc_obj_template.pk = None
                dpc_obj_template.parent_id = attachment_json[
                    "data_point_classification"]["id"]
                setattr(dpc_obj_template, attachment_json[
                        "chosen_data_form_config"]["last_level"] + "_id", dp.id)

                dpc_obj_template.data_form_config_id = attachment_json[
                    "chosen_data_form_config"]["id"]
                dpc_obj_template.save()
                for proj in projects:
                    DataPointClassificationPermission.objects.create(
                        project=proj, data_point_classification=dpc_obj_template)
                ids.append(dpc_obj_template.id)

            index_filter_dict({"id__in": ids})
            return self.create_response(request, self.build_bundle(request), response_class=http.HttpAccepted)

        else:
            raise BadRequest("No pk")

    def create_response(self, request, bundle, response_class=HttpResponse, **response_kwargs):
        """
        Extracts the common "which-format/serialize/return-response" cycle.
        Mostly a useful shortcut/hook.
        """
        if response_class == http.HttpCreated:
            bundle = self.prepare_newly_saved_data(bundle)
            # There has been a new object created - we must now index it
            for ob in bundle.data["tempobjects"]:
                ob["l0_permitted_projects"] = bundle.data[
                    "data_point_classification"].data["l0_permitted_projects"]

            elasticsearch_client.index_datapoint_classification({"objects": bundle.data["tempobjects"]},
                                                                index_name=elasticsearch_client.get_attachment_index_name(
                                                                    bundle.obj.id),
                                                                refresh=True,
                                                                decode_json=False)
            bundle.data["tempobjects"] = []

        desired_format = self.determine_format(request)

        serialized = self.serialize(request, bundle, desired_format)

        return response_class(content=serialized, content_type=build_content_type(desired_format), **response_kwargs)

def get_field_mappings(attachment_fields, project_fields):
    project_fields_dict = {field["resource_uri"] : field["elasticsearch_fieldname"] for field in project_fields}
    mappings = []
    for afield in attachment_fields:
        field_mapped_to_uri = afield.get("attachment_field_mapped_to", None)
        if field_mapped_to_uri:
            mappings.append((afield["elasticsearch_fieldname"], project_fields_dict[field_mapped_to_uri]))
    return mappings

class QueryResource(UserHydrate, ModelResource):

    """ A resource which saves a query for elasticsearch and then returns the result of the query"""
    created_by = fields.ForeignKey(
        "cbh_core_ws.resources.UserResource", 'created_by')
    query = CBHDictField(attribute='query')
    aggs = CBHDictField(attribute='aggs')
    filter = CBHDictField(attribute='filter')

    class Meta:
        queryset = Query.objects.all()
        filtering = {
            "filter": ALL_WITH_RELATIONS,
            "query": ALL_WITH_RELATIONS,
        }
        always_return_data = True  # required to add the elasticsearch data
        resource_name = 'cbh_queries/_search'
        #authorization = Authorization()
        default_format = 'application/json'
        include_resource_uri = True
        allowed_methods = ['post', 'get', ]
        default_format = 'application/json'
        serializer = ResultsExportXLSSerializer()
        authentication = SessionAuthentication()
        authorization = Authorization()

    def authorization_filter(self, request, filter_json):
        from cbh_datastore_ws.urls import api_name

        auth = DataClassificationProjectAuthorization()

        project_ids = auth.project_ids(request)
        pr = ProjectWithDataFormResource()

        puris = ["/%s/datastore/cbh_projects_with_forms/%d" %
                 (api_name, pid) for pid in project_ids]
        new_filter = {"bool": {
            "must": [
                filter_json,
                {"terms": {"l0_permitted_projects.raw": puris}}
            ]
        }}
        return new_filter

    def alter_detail_data_to_serialize(self, request, updated_bundle):
        es = elasticsearch_client.get_client()
        index_name = elasticsearch_client.get_index_name()
        if request.GET.get("index_name", None):
            index_name = request.GET.get("index_name")
        query_filter = self.authorization_filter(request, updated_bundle.data.get("filter", {"match_all": {}}))

        bod = {
            "aggs": updated_bundle.data.get("aggs", {}),
            "query": {
                        "bool": 
                            {
                                "must" : 
                                        [
                                            updated_bundle.data.get("query", {"match_all": {}}),
                                            {
                                                "filtered": {
                                                        "filter": query_filter
                                                 }
                                            },
                                        ]
                            }
                    },
            "sort": updated_bundle.data.get("sort", [{"id": {"order": "desc"}}]),
            "highlight": updated_bundle.data.get("highlight", {}),
        }
        if updated_bundle.data.get("_source", False):
            bod["_source"] = updated_bundle.data.get("_source", False)
       
        data = es.search(
            index_name,
            body=bod,
            from_=request.GET.get("from"),
            size=request.GET.get("size")
        )
        updated_bundle.data.update(data)
        return updated_bundle


    def save(self, bundle, skip_errors=False):
        ''' Add a random ID for now as we dont need to save the object '''
        self.is_valid(bundle)

        if bundle.errors and not skip_errors:
            raise ImmediateHttpResponse(
                response=self.error_response(bundle.request, bundle.errors))

        # Save FKs just in case.
        # revert to using saved search - it's the only way we can access the search params in the correct way for the various export methods
        #bundle.obj.id = randint(1,1000000000)
        bundle.obj.save()
        bundle.objects_saved.add(self.create_identifier(bundle.obj))
        bundle.request.GET = bundle.request.GET.copy()
        # Set the full parameter in the request GET object when saving stuff
        bundle.request.GET["full"] = True
        # Now pick up the M2M bits.

        return bundle

    def get_schema(self, request, **kwargs):
        """
        Returns a serialized form of the schema of the resource.
        Calls ``build_schema`` to generate the data. This method only responds
        to HTTP GET.
        Should return a HttpResponse (200 OK).
        """
        # self.method_check(request, allowed=['get'])
        # self.is_authenticated(request)
        # self.throttle_check(request)
        # self.log_throttled_access(request)
        # bundle = self.build_bundle(request=request)
        # self.authorized_read_detail(self.get_object_list(bundle.request), bundle)
        return self.create_response(request, self.build_schema())

    def create_response(self, request, data, response_class=HttpResponse, **response_kwargs):
        """
        Extracts the common "which-format/serialize/return-response" cycle.
        Mostly a useful shortcut/hook.
        """

        desired_format = self.determine_format(request)
        serialized = self.serialize(request, data, desired_format)
        rc = response_class(content=serialized, content_type=build_content_type(
            desired_format), **response_kwargs)

        if(desired_format == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'):
            rc['Content-Disposition'] = 'attachment; filename=results_export.xlsx'
        return rc


class MyToManyField(fields.ToManyField):

    def should_full_dehydrate(self, bundle, for_list):
        """Here we are not fully dehydrating if this is the last level in the hierarchy. 
        The reason for this is that there would be too much data. Therefore we page the bottom level
        data point classifications from elasticsearch"""
        return not bundle.obj.data_form_config.human_added


class NestedDataPointClassificationResource(Resource):

    class Meta(DataPointClassificationResource.Meta):
        resource_name = 'cbh_datapoint_classifications_nested'
        allowed_methods = ['get']

    def get_list(self, request, **kwargs):
        # pull out a nested list from elasticsearch
        pr = ProjectWithDataFormResource()
        request.GET = request.GET.copy()
        request.GET["from"] = 0
        request.GET["size"] = 10000
        objects = {}
        l0_objects = []
        
        project = Project.objects.get(
            project_key=request.GET.get("project_key"))
        for lev in [0,1,2]:
            post_data = {
                "_source": {
                    "include": [ "id", "level_from", "next_level", "modified", "data_form_config", "*.custom_field_config", "resource_uri", "parent_id", "*.resource_uri", "*.id",  "l%d" % lev+ ".project_data.*",],
                },
                "query":
                {
                    "bool":
                    {"must": [
                        {"term": {
                            "l0_permitted_projects.raw": pr.get_resource_uri(bundle_or_obj=project)}},
                        {"term": {"level_from.raw": "l%d" % lev}}
                    ]
                    },

                },
                "sort": {"created": {"order": "desc", "unmapped_type": "long"}}}

            qr = QueryResource()

            resp = qr.alter_detail_data_to_serialize(
                request, qr.build_bundle(request=request, data=post_data))
            for hit in resp.data["hits"]["hits"]:
                hit["_source"]["children"] = []
                objects[hit["_source"]["id"]] = hit["_source"]
                

        for key, obj in objects.items():
            if obj["parent_id"]:
                parent = objects.get(obj["parent_id"], None)
                if parent:
                    parent["children"].append(obj)
            else:
                l0_objects.append(obj)
        return HttpResponse(json.dumps({"objects": l0_objects}))

# #using this to accept autosave/draft save requests
# #and also return a list of saved drafts if required
# #and also return a single cached draft if reverting to a previous version
# class dict2obj(object):
#     """
#     Convert dictionary to object
#     @source http://stackoverflow.com/a/1305561/383912
#     """
#     def __init__(self, d):
#         self.__dict__['d'] = d

#     def __getattr__(self, key):
#         value = self.__dict__['d'][key]
#         if type(value) == type({}):
#             return dict2obj(value)

#         return value

# class DraftDataPointResource(Resource):
#     import time

#     current_milli_time = lambda: int(round(time.time() * 1000))

#     #setting up the fields I will be using so I don't have to create an unused Model
#     draft_key = fields.CharField(attribute='draft_key')
#     content = fields.CharField(attribute='content')

#     class Meta:
#         default_format = 'application/json'
#         resource_name = 'cbh_draft_data'
#         allowed_methods = ['get','post']
#         authentication = SessionAuthentication()
#         authorization = Authorization()


#     def prepend_urls(self):
#         return [
#             url(r"^(?P<resource_name>%s)/save_draft/$" % self._meta.resource_name,
#                 self.wrap_view('save_draft'), name="api_save_draft"),
#             url(r"^(?P<resource_name>%s)/$" % self._meta.resource_name,
#                 self.wrap_view('get_draft_list'), name="api_get_draft_list"),
#             url(r"^(?P<resource_name>%s)/get_draft/$" % self._meta.resource_name,
#                 self.wrap_view('get_draft'), name="api_get_draft"),

#         ]
#     """
#     item in the sesssion ('drafts') needs to be a list of dictionaries
#     each item contains draft_key (a millisecond timestamp) and the content
#     save_draft adds an entry to drafts
#     get_draft_list returns drafts
#     get draft looks for a supplied draft_key in drafts objects.

#     """

#     def save_draft(self, request, **kwargs):
#         #take the json data supplied and save to the session
#         #use the timestamp or current millis as a key - may be able to generate this in the front end
#         #print(request.GET)

#         if request.GET.get('content'):
#             #does drafts exist? if not, create it
#             drafts_obj = request.session.get('drafts', [])
#             if drafts_obj.length > 0:
#                 request.session['drafts'] = []

#             draft_obj = {}
#             draft_obj['draft_key'] = current_milli_time()
#             draft_obj['content'] = request.GET.get('content')
        
#         request.session[drafts].append(draft_obj)            

#         return HttpResponse(content=draft_key, content_type=self._meta.default_format)

#     def get_draft_list(self, request, **kwargs):
#         #get all of the drafts within the current session, if any
#         return_item = []
#         if request.session[drafts]:
#             return_item = request.session[drafts]
        
#         return HttpResponse(content=return_item, content_type=self._meta.default_format)

#     def get_draft(self, request, **kwargs):
#         #get the draft matching the timestamp based key (or other key)
#         if request.GET.get('draft_key'):
#             drafts = request.session[drafts]
#             for draft in drafts:
#                 if draft['draft_key'] == request.GET.get('draft_key'):
#                     return HttpResponse(content=draft['content'], content_type=self._meta.default_format)
#             #no match? send empty response
#             return HttpResponse(content={}, content_type=self._meta.default_format)
#         else:
#             return HttpResponse(content={}, content_type=self._meta.default_format)


#     def get_list(self, request):
#         drafts = request.session.get('drafts', [])
#         draft_list = []
#         for draft in drafts:
#             draft_list.append(dict2obj(draft))
#         return draft_list

