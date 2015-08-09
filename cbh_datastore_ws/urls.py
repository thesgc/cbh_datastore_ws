
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
api.register(ProjectWithDataFromResource())

urlpatterns = api.urls