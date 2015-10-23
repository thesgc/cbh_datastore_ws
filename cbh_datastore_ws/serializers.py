from tastypie.serializers import Serializer
import json
import dpath
from cbh_core_model.models import PinnedCustomField
from django.conf import settings
from django.db import models

class DataPointClassificationSerializer(Serializer):

    def to_json(self, data, options=None):
        simple_data = self.to_simple(data, options)
        key_cache = {}
        if simple_data.get("standardised", None):
            if simple_data.get("objects", []):
                for dpc in simple_data.get("objects", []):

                    dfc_json = simple_data["forms"].get(
                        dpc.get("data_form_config"))
                    for level in ["l0", "l1", "l2", "l3", "l4"]:
                        cfc = dfc_json[level]
                        if cfc:
                            for field in cfc["project_data_fields"]:
                                if "uox" in field["name"].lower():
                                    if "cbh_chembl_ws_extension" in settings.INSTALLED_APPS:
                                        CBHCompoundBatch = models.get_model("cbh_chembl_model_extension", "cbhcompoundbatch")
                                        image = CBHCompoundBatch.objects.get_image_for_assayreg(field, dpc, level)
                                        dpc["imgSrc"] = image
                                if field["standardised_alias_id"]:
                                    if not key_cache.get(field["standardised_alias_id"], None):
                                        key_cache[field["standardised_alias_id"]] = PinnedCustomField.objects.get(
                                            pk=field["standardised_alias_id"])
                                    path_to_copy = key_cache[
                                        field["standardised_alias_id"]].field_key
                                    field_value = dpc[level]["project_data"].get(
                                        field["elasticsearch_fieldname"], None)
                                    if field_value:
                                        # Set a jsonpath of the appropriate
                                        # value
                                        dpath.util.new(
                                            dpc, path_to_copy, field_value)
                                        dpath.util.new(
                                            dpc, path_to_copy[1:], field_value)
                                dpc[level]["project_data_all"] = " ".join(
                                    [unicode(value) for key, value in dpc[level]["project_data"].items()])
                                dpc[level]["project_data_fields_all"] = [
                                    unicode(key) for key, value in dpc[level]["project_data"].items() if value]

        return json.dumps(simple_data)
