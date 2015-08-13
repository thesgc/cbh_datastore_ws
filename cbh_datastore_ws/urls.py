
from django.conf.urls import patterns, url, include

from django.contrib import admin



from tastypie.api import Api


from cbh_datastore_ws.resources import *
from django.conf import settings
DEFAULT_API_NAME='chemblws'

try:
    api_name = settings.WEBSERVICES_NAME
except AttributeError:
    api_name = DEFAULT_API_NAME



api = Api(api_name=api_name  + "/datastore")

api.register(DataPointClassificationResource())
api.register(ProjectWithDataFormResource())
api.register(DataFormConfigResource())
api.register(DataPointProjectFieldResource())
# api.register(DataPointClassificationPermissionResource())
api.register(DataPointResource())
api.register(SimpleCustomFieldConfigResource())
api.register(L0DataPointProjectFieldResource())
api.register(L0FullCustomFieldResource())
api.register(L1DataPointProjectFieldResource())
api.register(L1FullCustomFieldResource())
api.register(L2DataPointProjectFieldResource())
api.register(L2FullCustomFieldResource())
api.register(L3DataPointProjectFieldResource())
api.register(L3FullCustomFieldResource())
api.register(L4DataPointProjectFieldResource())
api.register(L4FullCustomFieldResource())








urlpatterns = api.urls