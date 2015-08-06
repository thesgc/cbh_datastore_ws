=============================
cbh_datastore_ws 
=============================





This is the DataPointClassification API which is the main way to pull out data.

A bioactivity would look like this:

```
{
    "meta": {
        "limit": 20,
        "next": null,
        "offset": 0,
        "previous": null,
        "total_count": 2
    },
    "objects": [
        {
            "created": "2015-08-06T10:24:41.871087",
            "description": null,
            "id": 2,
            "l0": {
                "created": "2015-08-06T10:23:09.594629",
                "id": 2,
                "modified": "2015-08-06T10:31:22.568223",
                "project_data": {
                    "Description": "Test Assay"
                },
                "supplementary_data": {
                    "test": [
                        "test"
                    ]
                }
            },
            "l1": {
                "created": "2015-08-06T10:23:35.659511",
                "id": 3,
                "modified": "2015-08-06T10:23:35.660133",
                "project_data": {
                    "IC50 (nm)": 50
                },
                "supplementary_data": {}
            },
        "l2": null,
            "modified": "2015-08-06T10:24:41.872356",
            "project_id": 6
        },
        
    ]
}
```