from django.core.management.base import BaseCommand, CommandError
from django.http import HttpRequest

class Command(BaseCommand):

    def handle(self, *args, **options):
        from cbh_datastore_ws.resources import reindex_datapoint_classifications

        reindex_datapoint_classifications()
