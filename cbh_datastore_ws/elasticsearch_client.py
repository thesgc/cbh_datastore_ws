
from django.conf import settings
import elasticsearch
from django.core.exceptions import ImproperlyConfigured


import time
try:
    ES_PREFIX = settings.ES_PREFIX
except AttributeError:
    raise ImproperlyConfigured("You must set the index prefix for cbh datastore")
import json
ES_MAIN_INDEX_NAME = "cbh_datastore_index"

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




def index_datapoint_classification(data, index_name=get_index_name(), refresh=True):
    data = json.loads(data)
    batches = [data]
    if data.get("objects", False):
        batches = data["objects"]

    es = elasticsearch.Elasticsearch()
    
    store_type = "niofs"
    create_body = {
        "settings": {
            "index.store.type": store_type
        },
        
         "mappings" : {
            "_default_" : {
               "_all" : {"enabled" : True},
               
                "_source": {
                    "excludes": [
                      "*.project_data_all",
                    ]
                  }
               "dynamic_templates" : [ 

                {
                 "string_fields" : {
                   "match" : "*",
                   "match_mapping_type" : "string",
                   "mapping" : {
                     "type" : "string","store" : "no", "index_options": "docs","index" : "analyzed", "omit_norms" : True,
                       "fields" : {
                         "raw" : {"type": "string","store" : "no", "index" : "not_analyzed", "ignore_above" : 256}
                       }
                   }
                 }
               } 
            ]
        }
        }
    }
    # if(index_name == get_main_index_name()):
    #     create_body['mappings']['_source'] = { 'enabled':False }
    #index_name = get_temp_index_name(request, multi_batch_id)
    
    es.indices.create(
            index_name,
            body=create_body,
            ignore=400)
    
    bulk_items = []
    for item in batches:
        bulk_items.append({
                            "index" :
                                {
                                    "_id": str(item["id"]), 
                                    "_index": index_name,
                                    "_type": "data_point_classifications"
                                }
                            })
        bulk_items.append(item)
    #Data is not refreshed!
    es.bulk(body=bulk_items, refresh=refresh)



