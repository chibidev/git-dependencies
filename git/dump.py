import enum

class DumpException(Exception):
    pass

class DumpType(enum.Enum):
    Default, Header, Custom = range(0,3)

    @classmethod
    def from_string(cls, type_str):
        if type_str.lower() == 'default':
            return cls.Default
        elif type_str.lower() == 'header':
            return cls.Header
        elif type_str.lower() == 'custom':
            return cls.Custom
        else:
            raise DumpException('{} is not a valid dump type'.format(type_str))

    def __str__(self):
        return '{}'.format(self.name)
