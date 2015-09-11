# -*- coding: utf-8 -*-


from tastypie.resources import ModelResource, Resource , ALL, ALL_WITH_RELATIONS

from tastypie.serializers import Serializer
from cbh_core_ws.resources import CoreProjectResource, CustomFieldConfigResource, DataTypeResource, UserResource, CoreProjectResource, ProjectTypeResource
from cbh_datastore_model.models import DataPoint, DataPointClassification, DataPointClassificationPermission, Query
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
import inflection


from cbh_datastore_ws.authorization import DataClassificationProjectAuthorization

from cbh_core_ws.authorization import ProjectAuthorization, ProjectListAuthorization
from django.http import HttpResponse, HttpResponseNotFound, Http404


from django.db.models import Prefetch

from tastypie.utils.mime import determine_format, build_content_type

from tastypie import http

from cbh_datastore_ws import elasticsearch_client


from django.db.models import Max, Min
from django.http import HttpRequest



class DataPointProjectFieldResource(ModelResource):
    """Provides the schema information about a field that is required by front end apps"""
    handsontable_column = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    edit_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    edit_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    elasticsearch_fieldname = fields.CharField(null=True, blank=False, readonly=False, help_text=None)
    # filter_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    # filter_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)   
    # exclude_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    # exclude_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    # sort_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    # sort_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    # hide_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    # hide_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    # actions_form = fields.DictField(null=True, blank=False, readonly=False, help_text=None)
    # actions_schema = fields.DictField(null=True, blank=False, readonly=False, help_text=None)


    class Meta:
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




    def get_namespace(self, bundle):
        '''
            Hook to return the dotted path to this field based on the level and the name of the field
            The level name is formatted in the dehydrate method of the DataFormConfigResource
        '''
        return "{level}.project_data.%s" % ( bundle.obj.get_space_replaced_name())

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
        form["key"] = obj.get_space_replaced_name()
        form["title"] = obj.name
        form["description"] = obj.description
        form["disableSuccessState"] = True
        form["feedback"] = False
        # form["allowed_values"] = obj.allowed_values
        # form["part_of_blinded_key"] = obj.part_of_blinded_key
        searchitems = []
        data['default'] = obj.default
        if data["type"] == "array":
            data['default'] = obj.default.split(",")
        if obj.UISELECT in data.get("format", ""):
            
            form["placeholder"] = "Choose..."
            form["help"] = obj.description
            data['items'] = obj.get_items_simple()
            


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



    def dehydrate_elasticsearch_fieldname(self, bundle):
        return bundle.obj.get_space_replaced_name()


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
        return {"properties" :{bundle.obj.get_space_replaced_name() : self.get_field_values(bundle)[0]}}


    def dehydrate_actions_form(self, bundle):
        '''          '''
        return None

    def dehydrate_actions_schema(self, bundle):
        '''          '''
        return None





class SimpleCustomFieldConfigResource(ModelResource):
    '''Return only the project type and custom field config name as returning the full field list would be '''
    data_type = fields.ForeignKey("cbh_core_ws.resources.DataTypeResource", 'data_type', null=True, blank=False, default=None, full=True)
    project_data_fields = fields.ToManyField("cbh_datastore_ws.resources.DataPointProjectFieldResource", "pinned_custom_field", null=True, blank=False, default=None, full=True)
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






class DataFormConfigResource(ModelResource):
    name = fields.CharField(null=True,blank=True)
    last_level = fields.CharField(null=True,blank=True)
    l0 = fields.ForeignKey("cbh_datastore_ws.resources.SimpleCustomFieldConfigResource",'l0', null=True, blank=False, readonly=False, help_text=None, full=True)
    l1 = fields.ForeignKey("cbh_datastore_ws.resources.SimpleCustomFieldConfigResource",'l1', null=True, blank=False, readonly=False, help_text=None,full=True)
    l2 = fields.ForeignKey("cbh_datastore_ws.resources.SimpleCustomFieldConfigResource",'l2', null=True, blank=False, readonly=False, help_text=None, full=True)
    l3 = fields.ForeignKey("cbh_datastore_ws.resources.SimpleCustomFieldConfigResource",'l3', null=True, blank=False, readonly=False, help_text=None, full=True)
    l4 = fields.ForeignKey("cbh_datastore_ws.resources.SimpleCustomFieldConfigResource",'l4', null=True, blank=False, readonly=False, help_text=None,full=True)

    
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
<pre>
  _____
l0    |
l1    |
l2    |----- These fields all list the full 
l3    |     information about a level of the data based 
l4____|     upon its custom field configs - see below

</pre>
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
  ____
l0    |
l1    |
l2    |----- These fields all list the full 
l3    |     information about a level of the data based 
l4____|     upon its custom field configs - see below

</pre>
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


    def dehydrate_last_level(self, bundle):
        """Returns the last not null custom field config - useful in checking what level the ui should go to"""
        return bundle.obj.last_level()
        
    def dehydrate(self, bundle):
        for level in ["l1", "l2", "l3", "l4", "l0"]:
            levdata = bundle.data.pop(level)
            if level == bundle.data["last_level"]:
                bundle.data["main_cfc"] = levdata
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

    # def alter_list_data_to_serialize(self, request, data):
    #     """Add the level name to each of the fields that need a level name in them"""
    #     for level in ["l1", "l2", "l3", "l4", "l0"]:
    #         for item in data["objects"]:
    #             if item.data[level]:
    #                 for field in item.data[level].data["project_data_fields"]:
    #                     if field.data["handsontable_column"]["data"]:
    #                         field.data["handsontable_column"]["data"] = field.data["handsontable_column"]["data"].format(**{"level": level})
    #                     if field.data["elasticsearch_fieldname"]:
    #                         field.data["elasticsearch_fieldname"] = field.data["elasticsearch_fieldname"].format(**{"level": level})
    #     return data



    # def dehydrate_natural_key(self, bundle):
    #     return bundle.obj.natural_key()
        




class ProjectWithDataFormResource(ModelResource):
    project_type = fields.ForeignKey("cbh_datastore_ws.resources.ProjectTypeResource", 'project_type', blank=False, null=False, full=True)
    form_uris = fields.DictField(null=True)
    class Meta:

        excludes  = ("schemaform", "custom_field_config")
        queryset = Project.objects.all()
        authentication = SessionAuthentication()
        allowed_methods = ['get', 'post', 'put']        
        resource_name = 'cbh_projects_with_forms'
        authorization = ProjectListAuthorization()
        include_resource_uri = True
        default_format = 'application/json'
        serializer = Serializer()
        filtering = {
           "id" : ALL,
           "project_key" : ALL_WITH_RELATIONS,
        }        
        description =       {'api_dispatch_detail' : '''
A project is the top level item in the system:
project_type : For assay registration project type is not very important - it is just the top level lable
enabled_forms: Provides a list of the forms that are enabled for this project.
NOTE just because a project has aa certain form enabled DOES not give it permission to access all data created with that forms
This is done with the data form config permission objects

==========================================================
The project provides data about all levels of a data form configs that are attached to that project

A data form config's name is built up from its different custom field configs by combining their names and data types in order

<pre>
  _____
l0    |
l1    |
l2    |----- These fields all list the full 
l3    |     information about a level of the data based 
l4____|     upon its custom field configs - see below

</pre>
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

<pre>

  _____
l0    |
l1    |
l2    |----- These fields all list the full 
l3    |     information about a level of the data based 
l4____|     upon its custom field configs - see below

</pre>

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


    def dehydrate_form_uris(self, bundle):
        full_dataset = {"enabled_forms" : {}}
        tree_builder = {}
        root_object = None
        for dfc in bundle.obj.enabled_forms.all():
            root_object = dfc.get_all_ancestor_objects(bundle.request, tree_builder=tree_builder)
        for key, obj_list in tree_builder.iteritems():
            for i, obj in enumerate(obj_list):
                dfcres = DataFormConfigResource()
                bun = dfcres.build_bundle(obj=obj, request=bundle.request)
                bun = dfcres.full_dehydrate(bun)
                tree_builder[key][i] = bun.data["id"]
                full_dataset["enabled_forms"][bun.data["id"]] = bun.data

        root_obj = tree_builder.pop("root")
        full_dataset["root_data_form_config_id"] = root_obj[0]
        full_dataset["permitted_routes_tree"] = tree_builder

        return full_dataset



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




class MyForeignKey(fields.ForeignKey):
    def should_full_dehydrate(self, bundle, for_list):     
        return bundle.request.GET.get("full", None)


class DataPointClassificationResource(ModelResource):
    '''Returns individual rows in the object graph - note that the rows returned are denormalized data points '''
    created_by = fields.ForeignKey("cbh_core_ws.resources.UserResource", 'created_by', null=True, blank=True, full=True, default=None)
    data_form_config = fields.ForeignKey("cbh_datastore_ws.resources.DataFormConfigResource",'data_form_config')
    l0_permitted_projects = fields.ToManyField("cbh_datastore_ws.resources.ProjectWithDataFormResource", attribute="l0_permitted_projects", full=False)
    level_from = fields.CharField( null=True, blank=False, default=None)
    next_level = fields.CharField( null=True, blank=False, default=None)
    is_leaf_node = fields.BooleanField(default="false")
    l0 = MyForeignKey("cbh_datastore_ws.resources.DataPointResource", 'l0', null=True, blank=False, default=None, )
    l1 = MyForeignKey("cbh_datastore_ws.resources.DataPointResource", 'l1',null=True, blank=False, default=None,)
    l2 = MyForeignKey("cbh_datastore_ws.resources.DataPointResource", 'l2',null=True, blank=False, default=None, )
    l3 = MyForeignKey("cbh_datastore_ws.resources.DataPointResource", 'l3',null=True, blank=False, default=None, )
    l4 = MyForeignKey("cbh_datastore_ws.resources.DataPointResource", 'l4',null=True, blank=False, default=None,)
    parent_id = fields.IntegerField( attribute="parent_id", null=True)

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
        always_return_data = True  #Must be true so that the hook for elasticsearch indexing works
        queryset = DataPointClassification.objects.all()
        resource_name = 'cbh_datapoint_classifications'
        #authorization = Authorization()
        default_format = 'application/json'
        include_resource_uri = True
        allowed_methods = ['get', 'post', 'patch']
        default_format = 'application/json'
        serializer = Serializer()
        authentication = SessionAuthentication()
        authorization = DataClassificationProjectAuthorization()
        required_fields = {
            "l0_permitted_projects" : "Must contain a list of URIs for the projects that the user wants to add this datapoint and all of its children to.",
            "data_form_config" : "Must contain the URI of the data form config which was used to create this object and l0,1,2,3 and 4"
        }
        description = {"api_dispatch_detail":"""
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
    


    def get_object_list(self, request):
        return super(DataPointClassificationResource, self).get_object_list(request).prefetch_related(Prefetch("data_form_config")).prefetch_related(Prefetch("l0_permitted_projects"))


    def apply_filters(self, request, applicable_filters):
        pids = self._meta.authorization.project_ids(request)
        dataset = self.get_object_list(request).filter(**applicable_filters).filter(l0_permitted_projects__id__in=set(pids))
        return dataset.order_by("-modified")




    def hydrate_created_by(self, bundle):
        user = get_user_model().objects.get(pk=bundle.request.user.pk)
        bundle.obj.created_by = user
        
        return bundle

    def dehydrate_level_from(self, bundle):
        return bundle.obj.level_from()

    def dehydrate_next_level(self, bundle):
        next_level = ""
        if  bundle.obj.l4_id != 1:
            return "l5"
        if  bundle.obj.l3_id != 1:
            return "l4"
        if  bundle.obj.l2_id != 1:
            return  "l3"
        if  bundle.obj.l1_id != 1:
            return "l2"
        if  bundle.obj.l0_id != 1:
            return  "l1"
        return next_level

    def dehydrate_is_leaf_node(self, bundle):
        
        if  bundle.obj.l4_id != 1:
            return "true"
        if  bundle.obj.l3_id != 1:
            leaf_node_check_count = self.get_object_list(bundle.request).filter(data_form_config_id=bundle.obj.data_form_config_id).filter(l3_id=bundle.obj.l3_id).exclude(l4_id=1).count()
            if leaf_node_check_count == 0:
                return "true"
        if  bundle.obj.l2_id != 1:
            leaf_node_check_count = self.get_object_list(bundle.request).filter(data_form_config_id=bundle.obj.data_form_config_id).filter(l2_id=bundle.obj.l3_id).exclude(l3_id=1).count()
            if leaf_node_check_count == 0:
                return "true"
        if  bundle.obj.l1_id != 1:
            leaf_node_check_count = self.get_object_list(bundle.request).filter(data_form_config_id=bundle.obj.data_form_config_id).filter(l1_id=bundle.obj.l3_id).exclude(l2_id=1).count()
            if leaf_node_check_count == 0:
                return "true"
        if  bundle.obj.l0_id != 1:
            leaf_node_check_count = self.get_object_list(bundle.request).filter(data_form_config_id=bundle.obj.data_form_config_id).filter(l0_id=bundle.obj.l3_id).exclude(l1_id=1).count()
            if leaf_node_check_count == 0:
                return "true"
        return "false"    



    def save(self, bundle, skip_errors=False):
        ''' Moved the hydrate_m2m call to earlier in the method to ensure that there is a consistent readout for the project authorization '''
        self.is_valid(bundle)

        if bundle.errors and not skip_errors:
            raise ImmediateHttpResponse(response=self.error_response(bundle.request, bundle.errors))
        
        m2m_bundle = self.hydrate_m2m(bundle)

        # Check if they're authorized.
        if bundle.obj.pk:
            self.authorized_update_detail(self.get_object_list(bundle.request), bundle)
        else:
            self.authorized_create_detail(self.get_object_list(bundle.request), bundle)

        # Save FKs just in case.
        self.save_related(bundle)
        level_from = self.dehydrate_level_from(bundle)
        
        if level_from != "l0":
            parent_finder_dict = {"data_form_config_id" : bundle.obj.data_form_config_id}
            look_for_default = False
            for level in ["l0_id", "l1_id", "l2_id", "l3_id", "l4_id"]:
                #For all 
                if level == level_from + "_id":
                    look_for_default = True
                if look_for_default:
                    parent_finder_dict[level] = 1
                else:
                    parent_finder_dict[level] = getattr(bundle.obj, level)
                parent_finder_dict["data_form_config_id"] = bundle.obj.data_form_config_id
            parents = self.apply_filters(bundle.request, parent_finder_dict)
            count = parents.count()
            if count == 1:
                bundle.obj.parent = parents[0]
            else:
                raise BadRequest("Issue with parent ids, should be one to choose from found %d" % count) 

        # Save the main object.
        bundle.obj.save()
        bundle.objects_saved.add(self.create_identifier(bundle.obj))
        bundle.request.GET = bundle.request.GET.copy()
        #Set the full parameter in the request GET object when saving stuff
        bundle.request.GET["full"] = True
        # Now pick up the M2M bits.
        self.save_m2m(m2m_bundle)

        return bundle


    def create_response(self, request, data, response_class=HttpResponse, **response_kwargs):
        """
        Extracts the common "which-format/serialize/return-response" cycle.
        Mostly a useful shortcut/hook.
        """
        desired_format = self.determine_format(request)
        serialized = self.serialize(request, data, desired_format)
        if response_class == http.HttpCreated:
            #There has been a new object created - we must now index it
            elasticsearch_client.index_datapoint_classification(serialized)
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





def reindex_datapoint_classifications():
    offset = 0
    aggs = DataPointClassification.objects.aggregate(Max("id"), Min("id"))

    res = DataPointClassificationResource()
    req = HttpRequest()
    req.GET = req.GET.copy()
    req.GET["full"] = True
    for myid in range(aggs["id__min"], aggs["id__max"]):
        try:
            obj = DataPointClassification.objects.get(id=myid)
            bundle = res.build_bundle(obj=obj, request=req)
            bundle = res.full_dehydrate(bundle)
            bundle = res.alter_detail_data_to_serialize(req, bundle)
            resp = res.create_response(req, bundle)
            elasticsearch_client.index_datapoint_classification(resp.content, refresh=False)
        except ObjectDoesNotExist:
            pass
    time.sleep(1)




class QueryResource(ModelResource):
    """ A resource which saves a query for elasticsearch and then returns the result of the query"""
    created_by = fields.ForeignKey("cbh_core_ws.resources.UserResource", 'created_by', null=True, blank=True, full=True, default=None)
    query = fields.DictField(attribute='query')
    aggs = fields.DictField(attribute='aggs')
    filter = fields.DictField(attribute='filter')
    

    class Meta:
        queryset = Query.objects.all()
        always_return_data=True #required to add the elasticsearch data
        resource_name = 'cbh_queries/_search'
        #authorization = Authorization()
        default_format = 'application/json'
        include_resource_uri = True
        allowed_methods = [ 'post','get',]
        default_format = 'application/json'
        serializer = Serializer()
        authentication = SessionAuthentication()
        authorization = Authorization()

    def authorization_filter(self, request, filter_json):
        auth = DataClassificationProjectAuthorization()
        project_ids = auth.project_ids(request)
        pr = ProjectWithDataFormResource()
        from cbh_datastore_ws.urls import api_name

        puris = ["/%s/datastore/cbh_projects_with_forms/%d" % (api_name, pid) for pid in project_ids]
        new_filter = {"bool" : {
            "must" : [
                filter_json,
                {"terms" : {"l0_permitted_projects.raw" : puris }}
            ]
        }}
        return new_filter



    def alter_detail_data_to_serialize(self, request, updated_bundle):
        es = elasticsearch_client.get_client()

        data = es.search(
            elasticsearch_client.get_index_name(), 
            body={
                "filter": self.authorization_filter(request, updated_bundle.obj.filter), 
                "aggs": updated_bundle.obj.aggs,
                "query" : updated_bundle.obj.query,
                "sort": updated_bundle.data.get("sort", [])
            },  
            from_=request.GET.get("from"),  
            size=request.GET.get("size")
            )
        updated_bundle.data.update(data)
        return updated_bundle

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



class MyToManyField(fields.ToManyField):
    def should_full_dehydrate(self, bundle, for_list):   
        """Here we are not fully dehydrating if this is the last level in the hierarchy. 
        The reason for this is that there would be too much data. Therefore we page the bottom level
        data point classifications from elasticsearch"""
        return bundle.obj.level_from() != bundle.obj.data_form_config.last_level()






class NestedDataPointClassificationResource(DataPointClassificationResource):
    children = MyToManyField("self", attribute="children", full=True,  )

    class Meta(DataPointClassificationResource.Meta):
        resource_name = 'cbh_datapoint_classifications_nested'
        allowed_methods = ['get']
        include_resource_uri = False
        filtering = {
            "parent_id": ALL_WITH_RELATIONS,
            "data_form_config": ALL_WITH_RELATIONS,
            "l0_permitted_projects" : ALL_WITH_RELATIONS,
            "l0" : ALL_WITH_RELATIONS,
            "l1" : ALL_WITH_RELATIONS,
            "l2" : ALL_WITH_RELATIONS,
            "l3" : ALL_WITH_RELATIONS,
            "l4" : ALL_WITH_RELATIONS,
            "parent" : ALL_WITH_RELATIONS
        }








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

