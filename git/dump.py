import enum
import json

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

class TextDump:
    """ Dependency visitor that prints each dependency on the fly, during the visit. """

    def __init__(self, dump_type = DumpType.Default, customString = ""):
        self.dump_type = dump_type
        self.customString = customString

    def visit(self, repo, section, dependency):
        if (repo.config.has_option(section, 'freezed')):
            branch = repo.config[section]['freezed']
            upstream = dependency.revParse(repo.config[section]['freezed'], upstream = True, abbreviate = True)
        else:
            branch = dependency.currentBranch(upstream = False)
            upstream = dependency.currentBranch(upstream = True)
        hash = dependency.currentSha()

        if (self.dump_type == DumpType.Default):
            print('Dependency ' + section + ' following ' + branch + ' (tracking: ' + upstream + ') is now at rev ' + hash)
        elif (self.dump_type == DumpType.Header):
            sanitizedPath = section.replace('/', '_').replace(' ', '_').replace('-', '_').upper()
            print('#define ' + sanitizedPath + '_BRANCH "' + branch + '"')
            print('#define ' + sanitizedPath + '_REMOTE "' + upstream + '"')
            print('#define ' + sanitizedPath + '_HASH "' + hash + '"')
            print('')
        elif (self.dump_type == DumpType.Custom):
            dependencyName = section.split('/')[-1]
            log = self.customString
            log = log.replace("%dependencyName%", dependencyName)
            log = log.replace("%dependency%", section)
            log = log.replace("%branch%", branch)
            log = log.replace("%remoteBranch%", upstream)
            log = log.replace("%sha1%", hash)
            sanitizedName = dependencyName.replace('/', '_').replace(' ', '_').replace('-', '_').upper()
            log = log.replace("%sanitizedName%", sanitizedName)
            sanitizedPath = section.replace('/', '_').replace(' ', '_').replace('-', '_').upper()
            log = log.replace("%sanitizedPath%", sanitizedPath)
            print(log)

    def finish(self):
        pass


class OverrideDump:
    """ Dependency visitor that collects all dependencies as a map [repo URL]:[commit hash].
    The dump is written at the end, when all dependencies are collected.
    """

    def __init__(self):
        self.depStore = {}

    def visit(self, repo, section, dependency):
        url = repo.config[section]['url']
        existingHash = self.depStore.get(url)
        hash = dependency.currentSha()

        if(existingHash is not None and hash != existingHash):
            # Same repo checked out at a different commits? Something is wrong here, bail out.
            sys.exit('Inconsistent dependency tree (repo {})'.format(url))

        self.depStore[url] = hash

    def finish(self):
        print(json.dumps(self.depStore))
