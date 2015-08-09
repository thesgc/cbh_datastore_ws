from tastypie.resources import ModelResource, Resource
from tastypie.serializers import Serializer
from cbh_core_ws.resources import CoreProjectResource, CustomFieldConfigResource, DataTypeResource, UserResource, CoreProjectResource, ProjectTypeResource
from cbh_datastore_model.models import DataPoint, DataPointClassification
from cbh_core_model.models import PinnedCustomField, ProjectType, DataFormConfig, Project
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
        allowed_methods = ['get', ]
        default_format = 'application/json'
        authentication = SessionAuthentication()
        level = None



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





class SimpleCustomFieldConfigResource(CustomFieldConfigResource):
    '''Return only the project type and custom field config name as returning the full field list would be '''
    data_type = fields.ForeignKey(DataTypeResource, 'data_type', null=True, blank=False, default=None, full=True)
    project_data_fields = fields.ToManyField(DataPointProjectFieldResource, "pinned_custom_field")
    class Meta:
        excludes  = ("schemaform")









class FullCustomFieldConfigResource(CustomFieldConfigResource):
    '''Return only the project type and custom field config full object '''
    data_type = fields.ForeignKey(DataTypeResource, 'data_type', null=True, blank=False, default=None, full=True)
    class Meta:
        excludes  = ("schemaform")



class L1DataPointProjectFieldResource(DataPointProjectFieldResource):
    class Meta:
        level = "l1"

class L1FullCustomFieldResource(SimpleCustomFieldConfigResource):
    project_data_fields = fields.ToManyField(L1DataPointProjectFieldResource,'pinned_custom_field',full=True)


class L2DataPointProjectFieldResource(DataPointProjectFieldResource):
    class Meta:
        level = "l2"

class L2FullCustomFieldResource(SimpleCustomFieldConfigResource):
    project_data_fields = fields.ToManyField(L2DataPointProjectFieldResource,'pinned_custom_field',full=True)


class L3DataPointProjectFieldResource(DataPointProjectFieldResource):
    class Meta:
        level = "l3"

class L3FullCustomFieldResource(SimpleCustomFieldConfigResource):
    project_data_fields = fields.ToManyField(L3DataPointProjectFieldResource,'pinned_custom_field',full=True)


class L4DataPointProjectFieldResource(DataPointProjectFieldResource):
    class Meta:
        level = "l4"

class L4FullCustomFieldResource(SimpleCustomFieldConfigResource):
    project_data_fields = fields.ToManyField(L4DataPointProjectFieldResource,'pinned_custom_field',full=True)


class L5DataPointProjectFieldResource(DataPointProjectFieldResource):
    class Meta:
        level = "l5"

class L5FullCustomFieldResource(SimpleCustomFieldConfigResource):
    project_data_fields = fields.ToManyField(L5DataPointProjectFieldResource,'pinned_custom_field',full=True)




class DataFormConfigResource(ModelResource):

    l1 = fields.ForeignKey(L1FullCustomFieldResource,'l1', null=True, blank=False, readonly=False, help_text=None, full=True)
    l2 = fields.ForeignKey(L2FullCustomFieldResource,'l2', null=True, blank=False, readonly=False, help_text=None, full=True)
    l3 = fields.ForeignKey(L3FullCustomFieldResource,'l3', null=True, blank=False, readonly=False, help_text=None, full=True)
    l4 = fields.ForeignKey(L4FullCustomFieldResource,'l4', null=True, blank=False, readonly=False, help_text=None, full=True)
    l5 = fields.ForeignKey(L5FullCustomFieldResource,'l5', null=True, blank=False, readonly=False, help_text=None, full=True)



    class Meta:
        always_return_data = True
        queryset = DataFormConfig.objects.all()
        resource_name = 'cbh_data_form_config'
        #authorization = Authorization()
        include_resource_uri = True
        allowed_methods = ['get', ]
        default_format = 'application/json'
        authentication = SessionAuthentication()
        level = None



class ProjectWithDataFromResource(ModelResource):
    project_type = fields.ForeignKey(ProjectTypeResource, 'project_type', blank=False, null=False, full=True)
    enabled_forms = fields.ToManyField(DataFormConfigResource, "enabled_forms", full=True)

    class Meta:
        excludes  = ("schemaform")
        queryset = Project.objects.all()
        authentication = SessionAuthentication()
        allowed_methods = ['get']        
        resource_name = 'cbh_projects_with_forms'
        authorization = Authorization()
        include_resource_uri = False
        default_format = 'application/json'
        #serializer = Serializer()
        serializer = Serializer()
 
    def get_object_list(self, request):
        return super(ProjectWithDataFromResource, self).get_object_list(request).prefetch_related(Prefetch("project_type")).order_by('-modified')


    # def alter_list_data_to_serialize(self, request, bundle):
    #     '''Here we append a list of tags to the data of the GET request if the
    #     search fields are required'''
    #     userres = UserResource()
    #     userbundle = userres.build_bundle(obj=request.user, request=request)
    #     userbundle = userres.full_dehydrate(userbundle)
    #     bundle['user'] = userbundle.data

class DataPointResource(ModelResource):
    custom_field_config = fields.ForeignKey(SimpleCustomFieldConfigResource,'custom_field_config', null=True, blank=False, readonly=False, help_text=None, full=True)
    project_data = fields.DictField(attribute='project_data', null=True, blank=False, readonly=False, help_text=None)
    supplementary_data = fields.DictField(attribute='supplementary_data', null=True, blank=False, readonly=False, help_text=None)
    l0 = fields.ForeignKey("DataPointClassificationResource", 'l0', null=True, blank=False, default=None, full=True)
    l1 = fields.ForeignKey("DataPointClassificationResource", 'l1',null=True, blank=False, default=None, full=True)
    l2 = fields.ForeignKey("DataPointClassificationResource", 'l2',null=True, blank=False, default=None, full=True)
    l3 = fields.ForeignKey("DataPointClassificationResource", 'l3',null=True, blank=False, default=None, full=True)
    l4 = fields.ForeignKey("DataPointClassificationResource", 'l4',null=True, blank=False, default=None, full=True)




    class Meta:
        always_return_data = True
        queryset = DataPoint.objects.all()
        resource_name = 'cbh_datapoints'
        #authorization = Authorization()
        include_resource_uri = True
        allowed_methods = ['get', 'post', 'put']
        default_format = 'application/json'
        authentication = SessionAuthentication()





class DataPointClassificationResource(ModelResource):
    '''Returns individual rows in the object graph - note that the rows returned are denormalized data points '''
    created_by = fields.ForeignKey(UserResource, 'created_by', null=True, blank=True, full=True, default=None)

    l0 = fields.ForeignKey(DataPointResource, 'l0', null=True, blank=False, default=None, full=True)
    l1 = fields.ForeignKey(DataPointResource, 'l1',null=True, blank=False, default=None, full=True)
    l2 = fields.ForeignKey(DataPointResource, 'l2',null=True, blank=False, default=None, full=True)
    l3 = fields.ForeignKey(DataPointResource, 'l3',null=True, blank=False, default=None, full=True)
    l4 = fields.ForeignKey(DataPointResource, 'l4',null=True, blank=False, default=None, full=True)



    def hydrate_created_by(self, bundle):
        user = get_user_model().objects.get(pk=bundle.request.user.pk)
        bundle.obj.created_by = user
        
        return bundle

    class Meta:
        always_return_data = True
        queryset = DataPointClassification.objects.all()
        resource_name = 'cbh_datapoint_classifications'
        #authorization = Authorization()
        default_format = 'application/json'
        include_resource_uri = True
        allowed_methods = ['get', 'post', 'put']
        default_format = 'application/json'
        serializer = Serializer()
        authentication = SessionAuthentication()
        authorization = Authorization()
    





