from tastypie.serializers import Serializer
import json
import dpath
from cbh_core_model.models import PinnedCustomField


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

        return json.dumps(simple_data)
