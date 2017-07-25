import json

class Dump:
    def branchInfo(self, repo, section, dependency):
        if (repo.config.has_option(section, 'freezed')):
            branch = repo.config[section]['freezed']
            upstream = dependency.revParse(repo.config[section]['freezed'], upstream = True, abbreviate = True)
        else:
            branch = dependency.currentBranch(upstream = False)
            upstream = dependency.currentBranch(upstream = True)
        return branch, upstream

    def visit(self, repo, section, dependency):
        pass

    def finish(self):
        pass


class DefaultDump(Dump):
    """ Dependency visitor that prints default dump on the fly, during the visit. """

    def visit(self, repo, section, dependency):
        branch, upstream = self.branchInfo(repo, section, dependency)
        hash = dependency.currentSha()
        print('Dependency ' + section + ' following ' + branch + ' (tracking: ' + upstream + ') is now at rev ' + hash)


class HeaderDump(Dump):
    """ Dependency visitor that prints header dump on the fly, during the visit. """

    def visit(self, repo, section, dependency):
        branch, upstream = self.branchInfo(repo, section, dependency)
        hash = dependency.currentSha()
        sanitizedPath = section.replace('/', '_').replace(' ', '_').replace('-', '_').upper()
        print('#define ' + sanitizedPath + '_BRANCH "' + branch + '"')
        print('#define ' + sanitizedPath + '_REMOTE "' + upstream + '"')
        print('#define ' + sanitizedPath + '_HASH "' + hash + '"')
        print('')


class CustomDump(Dump):
    """ Dependency visitor that prints custom dump on the fly, during the visit. """

    def __init__(self, customString = ""):
        self.customString = customString

    def visit(self, repo, section, dependency):
        branch, upstream = self.branchInfo(repo, section, dependency)
        hash = dependency.currentSha()
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


class OverrideDump(Dump):
    """ Dependency visitor that collects all dependencies as a map [repo URL]:[commit hash].
    The dump is written at the end, when all dependencies are collected.
    """

    def __init__(self):
        self.depStore = {}

    def visit(self, repo, section, dependency):
        url = repo.config[section]['url']
        existingHash = self.depStore.get(url)
        hash = dependency.currentSha()

        if(existingHash and hash != existingHash):
            # Same repo checked out at a different commits? Something is wrong here, bail out.
            sys.exit('Inconsistent dependency tree (repo {})'.format(url))

        self.depStore[url] = hash

    def finish(self):
        print(json.dumps(self.depStore, sort_keys = True))
