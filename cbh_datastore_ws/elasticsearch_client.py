from django.conf import settings
import elasticsearch
from django.core.exceptions import ImproperlyConfigured
from django_rq import job
import json
from tastypie.exceptions import BadRequest

try:
    ES_PREFIX = settings.ES_PREFIX
except AttributeError:
    raise ImproperlyConfigured(
            "You must set the index prefix for cbh datastore")
import json

ES_MAIN_INDEX_NAME = "cbh_datastore_index"


def get_attachment_index_name(aid):
    return "%s__temp_attachment_sheet__%d" % (ES_PREFIX, aid)


def get_index_name():
    return ES_PREFIX + "__" + ES_MAIN_INDEX_NAME


def delete_main_index():
    es = elasticsearch.Elasticsearch()
    try:
        es.indices.delete(get_index_name())
    except:
        pass


def get_client():
    es = elasticsearch.Elasticsearch()
    return es


@job
def index_datapoint_classification(data, index_name=get_index_name(), refresh=True, decode_json=True):
    if decode_json:
        data = json.loads(data)
    batches = [data]
    if data.get("objects", "False") != "False":
        batches = data["objects"]

    es = elasticsearch.Elasticsearch(timeout=60)

    store_type = "niofs"
    create_body = {
        "settings": {
            "index.store.type": store_type
        },

        "mappings": {
            "_default_": {
                "_all": {"enabled": True},

                "_source": {
                    "excludes": [
                        "*.project_data_all",
                    ]
                },
                "dynamic_templates": [

                    {
                        "string_fields": {
                            "match": "*",
                            "match_mapping_type": "string",
                            "mapping": {
                                "type": "string", "store": "no", "index_options": "docs", "index": "analyzed",
                                "omit_norms": True,
                                "fields": {
                                    "raw": {"type": "string", "store": "no", "index": "not_analyzed",
                                            "ignore_above": 256}
                                }
                            }
                        }
                    }
                ]
            }
        }
    }

    es.indices.create(
            index_name,
            body=create_body,
            ignore=400)

    bulk_items = []
    for item in batches:
        bulk_items.append({
            "index":
                {
                    "_id": str(item["id"]),
                    "_index": index_name,
                    "_type": "data_point_classifications"
                }
        })
        bulk_items.append(item)
    data = es.bulk(body=bulk_items, refresh=refresh)
    if data["errors"]:
        raise BadRequest(data)
