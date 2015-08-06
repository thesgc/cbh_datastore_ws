from tastypie.resources import ModelResource, Resource
from tastypie.serializers import Serializer
from cbh_core_ws.resources import CoreProjectResource
from cbh_datastore_model.models import DataPoint, DataPointClassification
from tastypie import fields
from tastypie.authentication import SessionAuthentication



class DataPointResource(ModelResource):
    project_data = fields.DictField(attribute='project_data', null=True, blank=False, readonly=False, help_text=None)
    supplementary_data = fields.DictField(attribute='supplementary_data', null=True, blank=False, readonly=False, help_text=None)

    class Meta:
        always_return_data = True
        queryset = DataPoint.objects.all()
        resource_name = 'cbh_datapoints'
        #authorization = Authorization()
        include_resource_uri = False
        allowed_methods = ['get', 'post', 'put']
        default_format = 'application/json'
        authentication = SessionAuthentication()







class DataPointTreeResource(ModelResource):
    '''Returns individual datapoints '''
    project_id =  fields.IntegerField(attribute='project_id', blank=False, null=False, )
    l0 = fields.ForeignKey(DataPointResource, 'l0', null=True, blank=False, default=None, full=True)
    l1 = fields.ForeignKey(DataPointResource, 'l1',null=True, blank=False, default=None, full=True)
    l2 = fields.ForeignKey(DataPointResource, 'l2',null=True, blank=False, default=None, full=True)
    
    class Meta:
        always_return_data = True
        queryset = DataPointClassification.objects.all()
        resource_name = 'cbh_datapointclassifications'
        #authorization = Authorization()
        include_resource_uri = False
        allowed_methods = ['get', 'post', 'put']
        default_format = 'application/json'
        authentication = SessionAuthentication()



