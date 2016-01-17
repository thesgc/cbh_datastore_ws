



from tastypie.api import Api


from cbh_datastore_ws.resources import *
from django.conf import settings
DEFAULT_API_NAME = 'chemblws'

try:
    api_name = settings.WEBSERVICES_NAME
except AttributeError:
    api_name = DEFAULT_API_NAME


api = Api(api_name=api_name + "/datastore")

api.register(DataPointClassificationResource())
api.register(NestedDataPointClassificationResource())
api.register(ProjectWithDataFormResource())
api.register(DataFormConfigResource())
api.register(DataPointProjectFieldResource())
api.register(DataPointResource())
api.register(SimpleCustomFieldConfigResource())
api.register(FlowFileResource())
api.register(QueryResource())
api.register(AttachmentResource())


urlpatterns = api.urls

print(urlpatterns)
