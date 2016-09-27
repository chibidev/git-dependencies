
def generate_os_types(os_str):
    result = [x.strip().lower() for x in os_str.split(',')] if os_str != '' else []
    result = list(set(map(short_os_type_name, result)))
    return result;

def short_os_type_name(os_type):
    if (os_type.lower() == "windows"):
        return 'win'
    elif (os_type.lower() == 'darwin'):
        return 'mac'
    else:
        return os_type.lower()
