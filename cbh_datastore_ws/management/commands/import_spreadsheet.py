from django.core.management.base import BaseCommand, CommandError
import shortuuid
from flowjs.models import FlowFile 
from shutil import copyfile
from cbh_core_ws.parser import get_sheetnames, get_sheet
from cbh_datastore_ws.resources import DataPointClassificationResource, AttachmentResource, DataPointProjectFieldResource, FlowFileResource
from django.http import HttpRequest
from django.test import TestCase, RequestFactory
from django.contrib.auth.models import User
import json
class Command(BaseCommand):
    def handle(self, *args, **options):
        if len(args) != 2:
            raise CommandError('Usage: python manage.py import_spreadsheet [filename] [data point classification id]')
        from flowjs.models import FlowFile
        #Here we fake the flowfile system by creating an identifier
        two_letterg = shortuuid.ShortUUID()
        two_letterg.set_alphabet("ABCDEFGHJKLMNPQRSTUVWXYZ")
        code = two_letterg.random(length=20)
        ff = FlowFile.objects.create(identifier=code, original_filename=args[0])
        copyfile(args[0], ff.path)
        
        fact = RequestFactory()
        request = fact.get("/dev/datastore/cbh_flowfiles/%s/?format=json" % code)

        request.user = User.objects.get(pk=1)
        ffr = FlowFileResource()
        resp = ffr.get_detail(request, identifier=code)
        data = json.loads(resp.content) 
        
        print "Please paste the required sheet name:"
        #Need to add sheetnames to the flowfile API so can choose before creating the attachment as you need one attachment per sheet
        for sheetname in data["sheet_names"]:
            print sheetname
        sheetname = raw_input()
        fact = RequestFactory()
        request = fact.post("/dev/datastore/cbh_attachments/?format=json", json.dumps({
                "flowfile": "/dev/datastore/cbh_flowfiles/%s" % code,
                "data_point_classification":  "/dev/datastore/cbh_datapoint_classifications/" + args[1],
                "chosen_data_form_config" : "/dev/datastore/cbh_data_form_config/2",
                "sheet_name": sheetname
            }), content_type="application/json")
        request.user = User.objects.get(pk=1)
        ar = AttachmentResource()
        resp = ar.post_list(request)
        data = json.loads(resp.content) 
        print data["resource_uri"]

        for index, field in enumerate(data["attachment_custom_field_config"]["project_data_fields"]):
            field["attachment_field_mapped_to"] = field["mapped_to_form"]["titleMap"][index]["value"]

        fact = RequestFactory()
        request = fact.patch("/dev/datastore/cbh_datapoint_fields/?format=json", json.dumps({
                "objects" : data["attachment_custom_field_config"]["project_data_fields"]
            }), content_type="application/json")
        request.user = User.objects.get(pk=1)

        pfr = DataPointProjectFieldResource()
        resp = pfr.patch_list(request)
        print resp.status_code
        fact = RequestFactory()
        request = fact.post(
                data["resource_uri"] + "/save_temporary_data",
                "{}",
                 content_type="application/json",
            )
        request.user = User.objects.get(pk=1)
        ar.post_save_temp_data(request, pk=data["id"])


# document
# assay
# activities
