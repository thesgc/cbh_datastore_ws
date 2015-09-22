from django.core.management.base import BaseCommand, CommandError
import shortuuid
from flowjs.models import FlowFile 
from shutil import copyfile
from cbh_core_ws.parser import get_sheetnames, get_sheet
from cbh_datastore_ws.resources import DataPointClassificationResource, AttachmentResource
from django.http import HttpRequest
from django.test import TestCase, RequestFactory
from django.contrib.auth.models import User
import json
class Command(BaseCommand):
    def handle(self, *args, **options):
        if len(args) != 2:
            raise CommandError('Usage: python manage.py import_spreadsheet [filename] [data point classification id]')
        from flowjs.models import FlowFile
        two_letterg = shortuuid.ShortUUID()
        two_letterg.set_alphabet("ABCDEFGHJKLMNPQRSTUVWXYZ")
        code = two_letterg.random(length=20)
        ff = FlowFile.objects.create(identifier=code, original_filename=args[0])
        copyfile(args[0], ff.path)
        print "Please paste the required sheet name:"
        for sheetname in get_sheetnames(ff.path):
            print sheetname
        sheetname = raw_input()
        res = DataPointClassificationResource()
        fact = RequestFactory()
        request = fact.post("/dev/cbh_attachments/?format=json", json.dumps({
                "flowfile_id":ff.id,
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
            print field["mapped_to_form"]["titleMap"]
            field["attachment_field_mapped_to"] = field["mapped_to_form"]["titleMap"][index]["value"]

        

# document
# assay
# activities
