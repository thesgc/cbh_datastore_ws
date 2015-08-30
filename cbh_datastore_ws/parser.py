# import pandas as pd
# import numpy as np

# def is_true(item):
#     if str(item).lower() in ["y", "true", "yes"]:
#         return True
#     else:
#         return False


# def get_custom_field_config(filename, sheetname):
#     xls = pd.ExcelFile(filename)
#     data = xls.parse(sheetname, index_col=None, na_values=[''])
#     data.columns = ["name", "required", "description"]
#     data["required"] = data["required"].apply(is_true)
#     return data.T.to_dict().values()