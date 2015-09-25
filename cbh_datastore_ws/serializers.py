from tastypie.serializers import Serializer
import json
import dpath
class DataPointClassificationSerializer(Serializer):
    def to_json(self, data, options=None):
        simple_data = self.to_simple(data, options)
        if simple_data.get("standardised" , None):
            if simple_data.get("objects", []):
                for dpc in simple_data.get("objects", []):

                    dfc_json = dpc.pop("data_form_config")
                    for level in ["l0", "l1", "l2", "l3", "l4"]:
                        cfc = dfc_json[level]
                        if cfc:
                            for field in cfc["project_data_fields"]:
                                if field["standardised_alias"]:
                                    path_to_copy = field["standardised_alias"]["field_key"]
                                    field_value = dpc[level]["project_data"].get(field["elasticsearch_fieldname"], None)
                                    if field_value:
                                        #Set a jsonpath of the appropriate value
                                        dpath.util.new(dpc, path_to_copy, field_value)
                                        dpath.util.new(dpc, path_to_copy[1:], field_value)
                                dpc[level]["project_data_all"] = " ".join([unicode(value) for key, value in dpc[level]["project_data"].items()]) 
                    dpc["data_form_config"] = dfc_json["resource_uri"]

        return json.dumps(simple_data)