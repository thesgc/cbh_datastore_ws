


def is_true(item):
    if str(item).lower() in ["y", "true", "yes"]:
        return True
    else:
        return False


def get_custom_field_config(filename, sheetname):
    import pandas as pdr
    xls = pdr.ExcelFile(filename)
    data = xls.parse(sheetname, index_col=None, na_values=[''])
    data.columns = ["name", "required", "description"]
    data["required"] = data["required"].apply(is_true)
    
    data = data.fillna('')
    return data.T.to_dict().values()

def get_key_from_field_name(name):
    return name.replace(u" ", u"__space__")

def get_sheet(filename, sheetname):
    import pandas as pdr
    xls = pdr.ExcelFile(filename)
    data = xls.parse(sheetname, index_col=None, na_values=[''])
    data = data.fillna('')
    replace = [get_key_from_field_name(column) for column in data.columns]
    data.columns = replace
    return data.T.to_dict().values()