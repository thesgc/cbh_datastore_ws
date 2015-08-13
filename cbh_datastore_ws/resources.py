# -*- coding: utf-8 -*-


from tastypie.resources import ModelResource, Resource , ALL, ALL_WITH_RELATIONS

from tastypie.serializers import Serializer
from cbh_core_ws.resources import CoreProjectResource, CustomFieldConfigResource, DataTypeResource, UserResource, CoreProjectResource, ProjectTypeResource
from cbh_datastore_model.models import DataPoint, DataPointClassification, DataPointClassificationPermission
from cbh_core_model.models import PinnedCustomField, ProjectType, DataFormConfig, Project, CustomFieldConfig
from tastypie import fields
from tastypie.authentication import SessionAuthentication
from django.contrib.auth import get_user_model

from cbh_core_ws.resources import get_field_name_from_key
from cbh_core_ws.resources import get_key_from_field_name
import time
from copy import deepcopy
from tastypie.exceptions import BadRequest

from tastypie.authorization import Authorization

from django.db.models import Prefetch
from tastypie.http import HttpConflict
from tastypie.exceptions import ImmediateHttpResponse












class DataPointProjectFieldResource(ModelResource):
    """Provides the schema information about a field that is required by front end apps"""
    handsontable_column = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    edit_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    edit_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    filter_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    filter_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)   
    exclude_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    exclude_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    sort_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    sort_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    hide_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    hide_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    actions_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    actions_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)


    class Meta:
        always_return_data = True
        queryset = PinnedCustomField.objects.all()
        resource_name = 'cbh_datapoint_fields'
        #authorization = Authorization()
        include_resource_uri = True
        allowed_methods = ['get','post' ]
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


    def get_parent_key(self, bundle):
        return get_key_from_field_name(bundle.obj.custom_field_config.name)

    def get_field_key(self, bundle):
        return get_key_from_field_name(bundle.obj.custom_field_config.name)



    def get_namespace(self, bundle):
        '''hook to return the dotted path to this field based on the level and the name of the field'''
        return "%s.project_data.%s" % (self._meta.level, bundle.obj.get_space_replaced_name())

    def get_namespace_for_action_key(self, bundle, action_type):
        return action_type


    def dehydrate_hide_form(self, bundle):
        hide_form = { 
            "key" : self.get_namespace_for_action_key(bundle, "hide"),
            "type": "radiobuttons",
            "titleMap": [
                { "value": "show", "name": "Show" },
                { "value": "hide", "name": "Hide" }
            ]
        }
        return {"form" : hide_form}


    def dehydrate_hide_schema(self, bundle):
        hide_schema = {
            self.get_namespace_for_action_key(bundle, "hide"): {
                "type": "string",
                "enum": ["hide","show"]
              }
        }
        return {"properties" : hide_schema}



    def get_field_values(self,  bundle):
        obj = bundle.obj
        data =  deepcopy(obj.FIELD_TYPE_CHOICES[obj.field_type]["data"])

        data["title"] = obj.name
        data["placeholder"] = obj.description
        form = {}
        form["position"] = obj.position
        form["key"] = self.get_namespace(bundle)
        form["title"] = obj.name
        form["placeholder"] = obj.description
        # form["allowed_values"] = obj.allowed_values
        # form["part_of_blinded_key"] = obj.part_of_blinded_key
        searchitems = []
        if obj.UISELECT in data.get("format", ""):
            
            form["placeholder"] = "Choose..."
            form["help"] = obj.description

        
        if data.get("format", False) == obj.DATE:
            maxdate = time.strftime("%Y-%m-%d")
            form.update( {
                "minDate": "2000-01-01",
                "maxDate": maxdate,
                'type': 'datepicker',
                "format": "yyyy-mm-dd",
                'pickadate': {
                  'selectYears': True, 
                  'selectMonths': True,
                },
            })

        else:
            for item in ["options"]:
                stuff = data.pop(item, None)
                if stuff:
                    form[item] = stuff
        return (data, form)






    def dehydrate_handsontable_column(self, bundle):

        hotobj = { "title": bundle.obj.name, 
                    "data": self.get_namespace(bundle), 
                    "className": "htCenter htMiddle ", 
                    "renderer": "linkRenderer"}

        return hotobj

    def dehydrate_edit_form(self, bundle):
        '''          '''

        return {"form" : [self.get_field_values(bundle)[1]]}

    def dehydrate_edit_schema(self, bundle):
        '''          '''
        return {"properties" :{self.get_namespace(bundle) : self.get_field_values(bundle)[0]}}

    def dehydrate_filter_form(self, bundle):
        '''          '''
        filter_form = {
                          "htmlClass": "",
                          "key": self.get_namespace_for_action_key(bundle,"filter"),
                          "disableSuccessState": True,
                          "feedback": False,
                          "options": {
                          "refreshDelay": 0,
                            "async": {
                                "url": "tba",
                                "call": "dependencyInjectedBasedOnThisString"
                              }
                          }
                      },
        return {"form" : filter_form }

    def dehydrate_filter_schema(self, bundle):
        '''          '''
        schema = {
                           self.get_namespace_for_action_key(bundle, "filter"): { 
                              "type": "array", 
                              "format" : "uiselect",
                              "items" :[],
                              "placeholder": "Choose...",
                              "title": "Filter %s" % bundle.obj.name,                                                }

                                }
        return {"properties": schema }


    def dehydrate_exclude_form(self, bundle):
        '''          '''
        exclude_form = {
                          "htmlClass": "",
                          "key": self.get_namespace_for_action_key(bundle, "exclude"),
                          "disableSuccessState": True,
                          "feedback": False,
                          "options": {
                          "refreshDelay": 0,
                            "async": {
                                "url": "tba",
                                "call": "dependencyInjectedBasedOnThisString"
                              }
                          }
                      },
        return {"form" : exclude_form }

    def dehydrate_exclude_schema(self, bundle):
        '''          '''
        schema = {
                           self.get_namespace_for_action_key(bundle, "exclude"): { 
                              "type": "array", 
                              "format" : "uiselect",
                              "items" :[],
                              "placeholder": "Choose...",
                              "title": "Exclude %s" % bundle.obj.name,                                                }

                                }
        return {"properties": schema }


    def dehydrate_sort_form(self, bundle):
        hide_form = { 
            "key" : self.get_namespace_for_action_key(bundle, "sort"),
            "type": "radiobuttons",
            "titleMap": [
                { "value": "asc", "name": "A-Z" },
                { "value": "desc", "name": "Z-A" }
            ]
        }
        return {"form" : hide_form}


    def dehydrate_sort_schema(self, bundle):
        '''Note that the sort schema askes for a priority - this is to be used in applying the sorts'''
        hide_schema = {
           self.get_namespace_for_action_key(bundle, "sort"): {
                "type": "string",
                "enum": ["asc","desc"]
              },
              "sort_priority":{
                    "type": "integer"
              }
        }
        return {"properties" : hide_schema}




    def dehydrate_actions_form(self, bundle):
        '''          '''
        return None

    def dehydrate_actions_schema(self, bundle):
        '''          '''
        return None





class SimpleCustomFieldConfigResource(ModelResource):
    '''Return only the project type and custom field config name as returning the full field list would be '''
    data_type = fields.ForeignKey("cbh_core_ws.resources.DataTypeResource", 'data_type', null=True, blank=False, default=None, full=True)
    project_data_fields = fields.ToManyField("cbh_datastore_ws.resources.DataPointProjectFieldResource", "pinned_custom_field", null=True, blank=False, default=None)
    created_by = fields.ForeignKey("cbh_core_ws.resources.UserResource", 'created_by')

    class Meta:
        object_class = CustomFieldConfig
        queryset = CustomFieldConfig.objects.all()
        excludes  = ("schemaform")
        include_resource_uri = False
        resource_name = 'cbh_custom_field_config'
        authentication = SessionAuthentication()
        authorization = Authorization()
        include_resource_uri = True
        default_format = 'application/json'
        serializer = Serializer()
        filtering = {"id" : ALL}
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


    def hydrate_created_by(self, bundle):
        user = get_user_model().objects.get(pk=bundle.request.user.pk)
        bundle.obj.created_by = user
        
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









# def full_list(bundle):
#     if bundle.regest.GET.get("show_form", False):
#         return True
#     return False


class L0DataPointProjectFieldResource(DataPointProjectFieldResource):
    class Meta:
        level = "l0"
        resource_name="l0_cbh_custom_field_config"

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



class L0FullCustomFieldResource(SimpleCustomFieldConfigResource):
    project_data_fields = fields.ToManyField("cbh_datastore_ws.resources.L0DataPointProjectFieldResource",'pinned_custom_field',full=True)

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





class L1DataPointProjectFieldResource(DataPointProjectFieldResource):
    class Meta:
        level = "l1"
        resource_name="l1_cbh_custom_field_config"

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



class L1FullCustomFieldResource(SimpleCustomFieldConfigResource):
    project_data_fields = fields.ToManyField("cbh_datastore_ws.resources.L1DataPointProjectFieldResource",'pinned_custom_field',full=True)
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



class L2DataPointProjectFieldResource(DataPointProjectFieldResource):
    class Meta:
        level = "l2"
        resource_name="l2_cbh_custom_field_config"

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



class L2FullCustomFieldResource(SimpleCustomFieldConfigResource):
    project_data_fields = fields.ToManyField("cbh_datastore_ws.resources.L2DataPointProjectFieldResource",'pinned_custom_field',full=True)

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


class L3DataPointProjectFieldResource(DataPointProjectFieldResource):
    class Meta:
        level = "l3"
        resource_name="l3_cbh_custom_field_config"
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


class L3FullCustomFieldResource(SimpleCustomFieldConfigResource):
    project_data_fields = fields.ToManyField("cbh_datastore_ws.resources.L3DataPointProjectFieldResource",'pinned_custom_field',full=True)
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



class L4DataPointProjectFieldResource(DataPointProjectFieldResource):
    class Meta:
        level = "l4"
        resource_name="l4_cbh_custom_field_config"
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


class L4FullCustomFieldResource(SimpleCustomFieldConfigResource):
    project_data_fields = fields.ToManyField("cbh_datastore_ws.resources.L4DataPointProjectFieldResource",'pinned_custom_field',full=True)


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




class DataFormConfigResource(ModelResource):
    name = fields.CharField(null=True,blank=True)
    l0 = fields.ForeignKey("cbh_datastore_ws.resources.L0FullCustomFieldResource",'l0', null=True, blank=False, readonly=False, help_text=None, full=True)
    l1 = fields.ForeignKey("cbh_datastore_ws.resources.L1FullCustomFieldResource",'l1', null=True, blank=False, readonly=False, help_text=None, full=True)
    l2 = fields.ForeignKey("cbh_datastore_ws.resources.L2FullCustomFieldResource",'l2', null=True, blank=False, readonly=False, help_text=None, full=True)
    l3 = fields.ForeignKey("cbh_datastore_ws.resources.L3FullCustomFieldResource",'l3', null=True, blank=False, readonly=False, help_text=None, full=True)
    l4 = fields.ForeignKey("cbh_datastore_ws.resources.L4FullCustomFieldResource",'l4', null=True, blank=False, readonly=False, help_text=None, full=True)

    class Meta:
        filtering = {
           "id" : ALL
        }
        always_return_data = True
        queryset = DataFormConfig.objects.all()
        resource_name = 'cbh_data_form_config'
        #authorization = Authorization()
        include_resource_uri = True
        allowed_methods = ['get','post','put' ]
        default_format = 'application/json'
        authentication = SessionAuthentication()
        authorization = Authorization()
        description = {'api_dispatch_detail' : '''
Provides data about a all levels of a data form config. 

A data form config's name is built up from its different custom field configs by combining their names and data types in order
```
  _____
l0    |
l1    |
l2    |----- These fields all list the full 
l3    |     information about a level of the data based 
l4____|     upon its custom field configs - see below

```
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
```
  ____
l0    |
l1    |
l2    |----- These fields all list the full 
l3    |     information about a level of the data based 
l4____|     upon its custom field configs - see below

```
data_type: A string to describe what "sort" of data this is (fields will generally be the same as other objects of this data type but that is up to the curator)
==============================================
project_data_fields:
===============================================
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

    def dehydrate_name(self, bundle):
        bundle.data["name"] = bundle.obj.__unicode__()

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




class ProjectWithDataFormResource(ModelResource):
    project_type = fields.ForeignKey("cbh_datastore_ws.resources.ProjectTypeResource", 'project_type', blank=False, null=False, full=True)
    enabled_forms = fields.ToManyField("cbh_datastore_ws.resources.DataFormConfigResource", "enabled_forms", full=True)

    class Meta:
        filtering = {
           "id" : ALL
        }
        excludes  = ("schemaform", "custom_field_config")
        queryset = Project.objects.all()
        authentication = SessionAuthentication()
        allowed_methods = ['get', 'post', 'put']        
        resource_name = 'cbh_projects_with_forms'
        authorization = Authorization()
        include_resource_uri = True
        default_format = 'application/json'
        serializer = Serializer()
        filtering = {"id" : ALL}
        description =       {'api_dispatch_detail' : '''
A project is the top level item in the system:
project_type : For assay registration project type is not very important - it is just the top level lable
enabled_forms: Provides a list of the forms that are enabled for this project.
NOTE just because a project has aa certain form enabled DOES not give it permission to access all data created with that forms
This is done with the data form config permission objects

==========================================================
The project provides data about all levels of a data form configs that are attached to that project

A data form config's name is built up from its different custom field configs by combining their names and data types in order

```
  _____
l0    |
l1    |
l2    |----- These fields all list the full 
l3    |     information about a level of the data based 
l4____|     upon its custom field configs - see below

```
data_type: A string to describe what "sort" of data this is (fields will generally be the same as other objects of this data type but that is up to the curator)
=================================================
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
A project is the top level item in the system:
project_type : For assay registration project type is not very important - it is just the top level lable
enabled_forms: Provides a list of the forms that are enabled for this project.
NOTE just because a project has aa certain form enabled DOES not give it permission to access all data created with that forms
This is done with the data form config permission objects

==========================================================
The project provides data about all levels of a data form configs that are attached to that project

A data form config's name is built up from its different custom field configs by combining their names and data types in order

```
  _____
l0    |
l1    |
l2    |----- These fields all list the full 
l3    |     information about a level of the data based 
l4____|     upon its custom field configs - see below

```

data_type: A string to describe what "sort" of data this is (fields will generally be the same as other objects of this data type but that is up to the curator)
=================================================
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
        '''}

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



class DataPointResource(ModelResource):
    created_by = fields.ForeignKey("cbh_core_ws.resources.UserResource", 'created_by', null=True, blank=True, full=True, default=None)
    custom_field_config = fields.ForeignKey("cbh_datastore_ws.resources.SimpleCustomFieldConfigResource",'custom_field_config')
    project_data = fields.DictField(attribute='project_data', null=True, blank=False, readonly=False, help_text=None)
    supplementary_data = fields.DictField(attribute='supplementary_data', null=True, blank=False, readonly=False, help_text=None)
    class Meta:
        
        always_return_data = True
        queryset = DataPoint.objects.all()
        resource_name = 'cbh_datapoints'
        authorization = Authorization()
        include_resource_uri = True
        allowed_methods = ['get', 'post', 'put']
        authentication = SessionAuthentication()
        default_format = 'application/json'
        serializer = Serializer()
        description = {"api_dispatch_detail":"""
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


    def hydrate_created_by(self, bundle):
        user = get_user_model().objects.get(pk=bundle.request.user.pk)
        bundle.obj.created_by = user
        
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



class DataPointClassificationResource(ModelResource):
    '''Returns individual rows in the object graph - note that the rows returned are denormalized data points '''
    created_by = fields.ForeignKey("cbh_core_ws.resources.UserResource", 'created_by', null=True, blank=True, full=True, default=None)
    data_form_config = fields.ForeignKey("cbh_datastore_ws.resources.DataFormConfigResource",'data_form_config')
    l0_permitted_projects = fields.ToManyField("cbh_datastore_ws.resources.ProjectWithDataFormResource", attribute="l0_permitted_projects")
    l0 = fields.ForeignKey("cbh_datastore_ws.resources.DataPointResource", 'l0', null=True, blank=False, default=None, )
    l1 = fields.ForeignKey("cbh_datastore_ws.resources.DataPointResource", 'l1',null=True, blank=False, default=None, )
    l2 = fields.ForeignKey("cbh_datastore_ws.resources.DataPointResource", 'l2',null=True, blank=False, default=None, )
    l3 = fields.ForeignKey("cbh_datastore_ws.resources.DataPointResource", 'l3',null=True, blank=False, default=None, )
    l4 = fields.ForeignKey("cbh_datastore_ws.resources.DataPointResource", 'l4',null=True, blank=False, default=None, )



    def hydrate_created_by(self, bundle):
        user = get_user_model().objects.get(pk=bundle.request.user.pk)
        bundle.obj.created_by = user
        
        return bundle


    class Meta:
        filtering = {
            "data_form_config": ALL_WITH_RELATIONS,
            "l0_permitted_projects" : ALL_WITH_RELATIONS,
            "l0" : ALL_WITH_RELATIONS,
            "l1" : ALL_WITH_RELATIONS,
            "l2" : ALL_WITH_RELATIONS,
            "l3" : ALL_WITH_RELATIONS,
            "l4" : ALL_WITH_RELATIONS,
        }
        always_return_data = True
        queryset = DataPointClassification.objects.all()
        resource_name = 'cbh_datapoint_classifications'
        #authorization = Authorization()
        default_format = 'application/json'
        include_resource_uri = True
        allowed_methods = ['get', 'post', 'patch']
        default_format = 'application/json'
        serializer = Serializer()
        authentication = SessionAuthentication()
        authorization = Authorization()
        required_fields = {
            "l0_permitted_projects" : "Must contain a list of URIs for the projects that the user wants to add this datapoint and all of its children to.",
            "data_form_config" : "Must contain the URI of the data form config which was used to create this object and l0,1,2,3 and 4"
        }
        description = {"api_dispatch_detail":"""
Data Point Classification:
This is the index of all of the data points (nodes of data) on the system. Although the data is in the form of a tree, it is stored in a flat format
Each form that is associated with a project will have its own tree of data within that project
If the tree of data produced by a form looks like this then 

```
        l0 project_X 
        ├── l1 subproject_A
        │   ├── l2 assay_A
        │   │   ├── l3 bioactivity_V
        │   │   ├── l3 bioactivity_W
        │   │   └── l3 bioactivity_X
        │   └── l2 assay_B
        │       └── l4 bioactivity_Y
        └── l1 subproject_B
```
For each leaf node in the tree there will be one data point classification object
```
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
```

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
```
l0 project_X   
├── l1 subproject_A
│   ├── l2 assay_A
│   │   ├── l3 bioactivity_V
│   │   ├── l3 bioactivity_W
│   │   └── l3 bioactivity_X
│   └── l2 assay_B
│       └── l4 bioactivity_Y
└── l1 subproject_B
```

For each leaf node in the tree there will be one data point classification object
```
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
```

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
```
{
    "data_form_config":"/dev/datastore/cbh_data_form_config/5", 
    "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/9"] }
    "l0": {"project_data":{"fields": "based", "on": "the", "custom": "field","config": "go here"} , 
    "custom_field_config" : "/dev/datastore/cbh_custom_field_config/744"}
}
```
OR is could look like this:
```
{
    "data_form_config":{"pk":5}, 
    "l0_permitted_projects": [{"pk":5}] }
    "l0": {"project_data":{"fields": "based", "on": "the", "custom": "field","config": "go here"} , 
    "custom_field_config" : {"pk": 115}
}
```


To add an "l1" to the existing l0 the format should look like this:
```
{
    "data_form_config":"/dev/datastore/cbh_data_form_config/4", 
    "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] }
    "l0": "cbh_datapoints/10" ,
    "l1": {"project_data":{"fields": "based", "on": "the", "custom": "field","config": "go here"} , 
    "custom_field_config" : ""/dev/datastore/cbh_custom_field_configs/45"}
}
```
Once that "l1" object has been added ensure it has an id in the UI

Then, if the whole object is patched back in this case then only l1 will be updated
If there is NO ID or URI or pk in the l1 object then a new leaf will be created
```
{
    "id": 453,
    "data_form_config":"/dev/datastore/cbh_data_form_config/4", 
    "l0_permitted_projects": ["/dev/datastore/cbh_projects_with_forms/8"] }
    "l0": "cbh_datapoints/10" ,
    "l1": {"id":999, project_data":{"fields": "deifferent", "on": "values", "custom": "this time","config": "go here"} , 
    "custom_field_config" : ""/dev/datastore/cbh_custom_field_configs/45"}
}
```
"""
,



}
    

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

            # We didn't get it, so maybe we created it but haven't saved it
            if related_obj is None:
                related_obj = bundle.related_objects_to_save.get(field_object.attribute, None)

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

                try: DataPointClassificationPermission.objects.get_or_create(**kwargs)
                except IntegrityError: continue

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



class DataPointClassificationPermissionResource(ModelResource):
    data_point_classification = fields.ForeignKey("cbh_datastore_ws.resources.DataPointClassificationResource",'data_point_classification')
    project = fields.ForeignKey("cbh_datastore_ws.resources.ProjectWithDataFormResource",'project')

    def hydrate_created_by(self, bundle):
        user = get_user_model().objects.get(pk=bundle.request.user.pk)
        bundle.obj.created_by = user
        return bundle

    class Meta:
        filtering = {
            "project": ALL_WITH_RELATIONS
        }
        always_return_data = True
        queryset = DataPointClassificationPermission.objects.all()
        resource_name = 'cbh_datapoint_classification_permissions'
        #authorization = Authorization()
        default_format = 'application/json'
        include_resource_uri = True
        allowed_methods = ['get', 'post', 'put']
        default_format = 'application/json'
        serializer = Serializer()
        authentication = SessionAuthentication()
        authorization = Authorization()

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

