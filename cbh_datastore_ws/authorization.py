from tastypie.authorization import Authorization
from tastypie.exceptions import TastypieError, Unauthorized, BadRequest
import logging
logger = logging.getLogger(__name__)
logger_debug = logging.getLogger(__name__)
from cbh_core_model.models import Project
from cbh_core_ws.authorization import get_all_project_ids_for_user_perms








class DataClassificationProjectAuthorization(Authorization):
    """
    Uses permission checking from ``django.contrib.auth`` to map
    ``POST / PUT / DELETE / PATCH`` to their equivalent Django auth
    permissions.

    Both the list & detail variants simply check the model they're based
    on, as that's all the more granular Django's permission setup gets.
    """


    def login_checks(self, request, model_klass, perms=None):

        # If it doesn't look like a model, we can't check permissions.
        # if not model_klass or not getattr(model_klass, '_meta', None):
        #     print "improper_setup_of_authorization"
        #     raise Unauthorized("improper_setup_of_authorization")
        # User must be logged in to check permissions.
        if not hasattr(request, 'user'):
            print "no_logged_in_user"
            raise Unauthorized("no_logged_in_user")


 

    def read_detail(self, object_list, bundle):

        self.login_checks(bundle.request, bundle.obj.__class__)
        pids = get_all_project_ids_for_user_perms(bundle.request.user.get_all_permissions(), ["editor","viewer"])
        allowed = False
        if bundle.obj.l0_permitted_projects.count() == 0:
            raise BadRequest("You must specify at least one project")
        for projbundle in bundle.obj.l0_permitted_projects.all():
            #If any one project is not allowed to be edited then unauthorized
            if projbundle.id in pids:
                allowed = True
            else:
                allowed = False
                break
        if allowed:
            return True
        raise Unauthorized("not authroized for project")





    def create_list(self, object_list, bundle):
        raise BadRequest("Creating a list is not yet authorized")



    def update_list(self, object_list, bundle):
        raise BadRequest("Creating a list is not yet authorized")





    def project_ids(self, request, ):
        pids = get_all_project_ids_for_user_perms( request.user.get_all_permissions(), ["editor","viewer",] )
        return pids











    def create_detail(self, object_list, bundle):
        self.login_checks(bundle.request, bundle.obj.__class__)
        pids = get_all_project_ids_for_user_perms(bundle.request.user.get_all_permissions(), ["editor",])
        allowed = False
        if len(bundle.data["l0_permitted_projects"]) == 0:
            raise BadRequest("You must specify at least one project")
        for projbundle in bundle.data["l0_permitted_projects"]:
            #If any one project is not allowed to be edited then unauthorized
            if projbundle.obj.id in pids:
                allowed = True
            else:
                allowed = False
                break
        if allowed:
            return True
        raise Unauthorized("not authroized for project")



    def update_detail(self, object_list, bundle):
        self.login_checks(bundle.request, bundle.obj.__class__)
        pids = get_all_project_ids_for_user_perms(bundle.request.user.get_all_permissions(), ["editor",])
        allowed = False
        if len(bundle.data["l0_permitted_projects"]) == 0:
            raise BadRequest("You must specify at least one project")
        for projbundle in bundle.data["l0_permitted_projects"]:
            #If any one project is not allowed to be edited then unauthorized
            if projbundle.obj.id in pids:
                allowed = True
            else:
                allowed = False
                break
        if allowed:
            return True
        raise Unauthorized("not authroized for project")









    def read_list(self, object_list, bundle):
        return object_list










