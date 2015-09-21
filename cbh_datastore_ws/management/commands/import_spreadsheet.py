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
                "data_point_classification_id":  int(args[1]),
                "sheet_name": sheetname
            }), content_type="application/json")
        request.user = User.objects.get(pk=1)
        ar = AttachmentResource()
        ar.post_list(request)

# document
# assay
# activities
