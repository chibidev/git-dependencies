import configparser
import os
import os.path
import sys
import shutil

from cmdtask import Task

GITDEPENDS_FILE = '.gitdepends'

class GitRepository:
    def __init__(self, url='', path='.'):
        self.repositoryPath = path
        self.gitPath = None
        self.remoteURL = url

        if (os.path.exists(self.repositoryPath)):
            self.__findGitRoot()
            self.__findGitDirectory()

    def _shouldUsePools(self):
        task = Task('which').run(['git-pool'])
        if (task.exitCode() != 0):
            return False
        else:
            return True

    def clone(self, branch=None):
        if (os.path.exists(self.repositoryPath)):
            return
        arguments = []
        if (self._shouldUsePools()):
            arguments = ['pool']
        arguments += ['clone', '--recursive']
        if (branch != None):
            arguments += ['--branch', branch]
        arguments += [self.remoteURL, self.repositoryPath]

        task = Task('git')
        task.run(arguments)
        if (task.exitCode() != 0):
            raise ValueError(task.output)

        self.__findGitRoot()
        self.__findGitDirectory()

    def checkout(self, ref):
        currentBranch = self.currentBranch(upstream = False)
        # TODO check if ref is freezed (sha1)
        if (currentBranch != ref):
            task = self._runGitTask(['checkout', ref])

    def fetch(self, remote, ref):
        task = self._runGitTask(['fetch', remote, ref])
        # TODO log

    def integrateChanges(self, ref):
        fetchHead = self._runGitTask(['rev-parse', 'FETCH_HEAD']).output
        head = self._runGitTask(['rev-parse', 'HEAD']).output

        if (fetchHead == head):
            # TODO verbose log
            return
        logArgs = ['log', '--oneline', head + '..' + fetchHead]
#		if (curses.has_colors()):
        logArgs += ['--color=always']
        logTask = self._runGitTask(logArgs)
        if (logTask.output != ''):
            print('Commits integrated into ' + self.repositoryPath + ':')
            for line in iter(logTask.output.splitlines()):
                print("\t" + line)
        self._runGitTask(['rebase', '--autostash']).output

    def updateSubmodules(self, recursive):
        # for submodule in self.submodules():
        # 	print(submodule)
        args = ['submodule', 'update', '--init']
        if (recursive):
            args += ['--recursive']
        self._runGitTask(args, False)

    def currentBranch(self, upstream=False):
        return self.revParse('HEAD', upstream, True)

    def currentSha(self):
        return self.revParse('HEAD')

    def commit(self, message, files=[]):
        arguments = ['commit', '-m', message, '--'] + files
        self._runGitTask(arguments).output

    def revParse(self, rev, upstream=False, abbreviate=False):
        if (upstream):
            rev += '@{upstream}'

        args = ['rev-parse']
        if (abbreviate):
            args += ['--abbrev-ref']

        args += [rev]

        return self._runGitTask(args).output

    def submodules(self):
        submodules = []
        self._runGitTask(['submodule', 'init'])
        for path in iter(self._runGitTask(['submodule', 'foreach', '-q', 'echo $path']).output.splitlines()):
            submodules += [path]
        return submodules

    def setRemoteURL(self, remote, url):
        self._runGitTask(['remote', 'set-url', remote, url])

    def isRefValid(self, ref):
        exitCode = self._runGitTask(['rev-parse', '--verify', ref], exitOnError = False).exitCode()
        return exitCode == 0

    def _runGitTask(self, arguments, useConfig=True, exitOnError=True):
        wd = os.getcwd()
        if (useConfig):
            arguments = ['--work-tree=' + self.repositoryPath] + arguments
            if (self.gitPath != None):
                arguments = ['--git-dir=' + self.gitPath] + arguments
        else:
            os.chdir(self.repositoryPath)

        # print('zserhardt@zserhardt-iMac:' + os.getcwd() + '$ git ' + '
        # '.join(arguments))

        task = Task('git').run(arguments)
        if (task.exitCode() != 0 and exitOnError):
            print(task.output, file=sys.stderr)
            sys.exit(task.exitCode())

        if (not useConfig):
            os.chdir(wd)

        return task

    def __findGitRoot(self):
        wd = os.getcwd()
        os.chdir(self.repositoryPath)
        self.repositoryPath = os.path.abspath(self._runGitTask(['rev-parse', '--show-toplevel']).output)
        os.chdir(wd)

    def __findGitDirectory(self):
        if (not os.path.exists(self.repositoryPath)):
            return

        wd = os.getcwd()
        os.chdir(self.repositoryPath)
        task = self._runGitTask(['rev-parse', '--git-dir'])
        if (task.exitCode() == 0):
            self.gitPath = os.path.abspath(task.output)
        os.chdir(wd)

class GitDependenciesRepository(GitRepository):
    dependencyStore = {}
    def __init__(self, url='', path='.'):
        super().__init__(url, path)

        self.config = None

        self.__loadDependenciesFile()
        # atexit.register(self.__saveDependenciesFile)

    def clone(self, branch='master'):
        super().clone(branch)
        self.__loadDependenciesFile()

    def checkout(self, ref):
        super().checkout(ref)
        self.config = None
        self.__loadDependenciesFile()

    def addDependency(self, url, path, ref='master'):
        if (os.path.exists(path) and (os.listdir(path) != [])):
            raise ValueError('%s is not empty' % path)

        if (self.config == None):
            self.config = configparser.ConfigParser()

        self.config.add_section(path)
        self.config[path]['url'] = url
        self.config[path]['ref'] = ref

        # TODO should not do it here
        with open('.gitignore', 'a') as ignoreFile:
            ignoreFile.write(path + os.linesep)

        self.__saveDependenciesFile()

    def removeDependency(self, path):
        self.config.remove_section(path)

    def updateDependencies(self, path='*', recursive=False):
        if (self.config == None):
            return
        cleanPath = self.__cleanPath(path)
        if (cleanPath == '*'):
            sections = self.config.sections()
        else:
            sections = [cleanPath]
        for p in sections:
            dependencyPath = os.path.join(self.repositoryPath, p)

            if (not os.path.exists(dependencyPath) and self.__canCreateSymlink(dependencyPath, p)):
                self.__createSymlink(dependencyPath, p)
                continue
            elif(self.__isSymlink(dependencyPath) and self.__canCreateSymlink(dependencyPath, p)):
                self.__updateSymlink(dependencyPath, p)
                continue
            elif(self.__isSymlink(dependencyPath) and not self.__canCreateSymlink(dependencyPath, p)):
                self.__removeSymlink(dependencyPath)

            d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)
            if (not os.path.exists(dependencyPath)):
                print(dependencyPath + ' was not found, cloning into dependency...')
                if (self.config.has_option(p, 'freezed')):
                    d.clone(self.config[p]['freezed'])
                    d.checkout(self.config[p]['ref'])
                else:
                    d.clone(self.config[p]['ref'])
            else:
                d.setRemoteURL('origin', self.config[p]['url'])
                if (self._shouldUsePools()):
                    task = self._runGitTask(['pool', 'relink', p, self.config[p]['url']])
                    if (task.exitCode() != 0):
                        print(task.output, file=sys.stderr)
                        sys.exit(task.exitCode())

                print('Updating ' + dependencyPath)
                if (self.config.has_option(p, 'freezed')):
                    d.fetch('origin', self.config[p]['freezed'])
                    d.checkout(self.config[p]['ref'])
                else:
                    d.fetch('origin', self.config[p]['ref'])
                    d.checkout(self.config[p]['ref'])
                    d.integrateChanges(self.config[p]['ref'])
                d.updateSubmodules(recursive)

        for p in sections:
            dependencyPath = os.path.join(self.repositoryPath, p)
            if(recursive and not self.__isSymlink(dependencyPath)):
                d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)
                d.__loadDependenciesFile()
                d.updateDependencies('*', recursive)

    def dumpDependency(self, path='*', recursive=False, dumpHeader=False):
        if (self.config == None):
            return
        cleanPath = self.__cleanPath(path)
        if (cleanPath == '*'):
            sections = self.config.sections()
        else:
            sections = [cleanPath]
        for p in sections:
            dependencyPath = os.path.join(self.repositoryPath, p)
            if (self.__isSymlink(dependencyPath)):
                realPath = self.__resolveSymlinkRealPath(dependencyPath)
                print(p + " is a symlink to " + realPath + ", skipping from dump.")
                continue

            d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)
            if (self.config.has_option(p, 'freezed')):
                branch = self.config[p]['freezed']
                upstream = d.revParse(self.config[p]['freezed'], upstream = True, abbreviate = True)
            else:
                branch = d.currentBranch(upstream = False)
                upstream = d.currentBranch(upstream = True)
            hash = d.currentSha()

            if (not dumpHeader):
                print('Dependency ' + p + ' following ' + branch + ' (tracking: ' + upstream + ') is now at rev ' + hash)
            else:
                sanitizedPath = p.replace('/', '_').replace(' ', '_').replace('-', '_').upper()
                print('#define ' + sanitizedPath + '_BRANCH "' + branch + '"')
                print('#define ' + sanitizedPath + '_REMOTE "' + upstream + '"')
                print('#define ' + sanitizedPath + '_HASH "' + hash + '"')
                print('')
            if (recursive):
                d.dumpDependency('*', recursive, dumpHeader)

    def setDependency(self, path, ref):
        if (self.config == None):
            return
        if (path == '' or ref == ''):
            print('Usage: set <path> <ref>')
            return

        p = self.__cleanPath(path)
        if (self.config.has_section(p) != True):
            print('Path cannot be found in gitdepends: ' + p)
            return

        dependencyPath = os.path.join(self.repositoryPath, p)

        if(not os.path.exists(dependencyPath)):
            self.updateDependencies(path)

        if(self.__isSymlink(dependencyPath)):
            realPath = self.__resolveSymlinkRealPath(dependencyPath)
            sys.exit(p + ' is a symlink to '+ realPath +'. Terminating operation.')

        d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)

        refIsInRemote = ref.find('origin/') == 0

        if (refIsInRemote):
            if (not d.isRefValid(ref)):
                print('Error: unknown ref: ' + ref)
                return
        else:
            if (not d.isRefValid(ref)):
                print('Warning: ref is invalid: ' + ref + '. Checking remote')
                remoteRef = 'origin/' + ref
                if (not d.isRefValid(remoteRef)):
                    print('Error: unknown ref: ' + ref)
                    return
        
        self.config[p]['ref'] = ref
        self.__saveDependenciesFile()

    def freezeDependency(self, path='*', recursive=False):
        if (self.config == None):
            return
       
        cleanPath = self.__cleanPath(path)
        if (cleanPath == '*'):
            sections = self.config.sections()
        else:
            sections = [cleanPath]
        for p in sections:
            if 'freezed' in self.config[p]:
                continue

            dependencyPath = os.path.join(self.repositoryPath, p)
            if (not os.path.exists(dependencyPath)):
                self.updateDependencies(p, False)
            
            d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)
            if (recursive):
                d.freezeDependency('*', recursive)

            hash = d.currentSha()
            self.config[p]['freezed'] = self.config[p]['ref']
            self.config[p]['ref'] = hash

            self.updateDependencies(p, False)
        self.__saveDependenciesFile()
        self.commit(message = 'Freezing dependencies', files = [GITDEPENDS_FILE])

    def unfreezeDependency(self, path='*', recursive=False):
        if (self.config == None):
            return

        cleanPath = self.__cleanPath(path)
        if (cleanPath == '*'):
            sections = self.config.sections()
        else:
            sections = [cleanPath]
        for p in sections:
            if 'freezed' not in self.config[p]:
                continue

            self.config[p]['ref'] = self.config[p]['freezed']
            self.config.remove_option(p, 'freezed')

            self.updateDependencies(p, False)

            d = GitDependenciesRepository(self.config[p]['url'], os.path.join(self.repositoryPath, p))
            if (recursive):
                d.unfreezeDependency('*', recursive)

            # self.checkout(self.config[p]['ref'])
        self.__saveDependenciesFile()
        self.commit(message = 'Unfreezing dependencies', files = [GITDEPENDS_FILE])

    def foreachDependency(self, command, recursive=False):
        if (self.config == None):
            return

        runCommand = command
        if (runCommand.startswith('!sh ')):
            runCommand = command[4:]
            i = runCommand.index(' ')
            task = Task(runCommand[:i])
            runCommand = runCommand[i + 1:]
        else:
            task = Task('git')

        for p in self.config.sections():
            dependencyPath = os.path.join(self.repositoryPath, p)
            if (self.__isSymlink(dependencyPath)):
                realPath = self.__resolveSymlinkRealPath(dependencyPath)
                print(p + " is a symlink to " + realPath + ", skipping from foreach.")
                continue

            d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)
            wd = os.getcwd()
            os.chdir(d.repositoryPath)
            task.run(runCommand.split(' '))
            if (task.output != ''):
                print(task.output, file=sys.stderr)
            if (task.exitCode() != 0):
                sys.exit(task.exitCode())
            os.chdir(wd)
            if (recursive):
                d.foreachDependency(command, True)

    def ensureNoSymlinkExistsInDependencySubtree(self, path='*', recursive=False):
        if (self.config == None):
            return
        
        cleanPath = self.__cleanPath(path)
        if (cleanPath == '*'):
            sections = self.config.sections()
        else:
            sections = [cleanPath]

        for p in sections:
            dependencyPath = os.path.join(self.repositoryPath, p)

            if (not os.path.exists(dependencyPath)):
                self.updateDependencies(p, False)

            if (self.__isSymlink(dependencyPath)):
                realPath = self.__resolveSymlinkRealPath(dependencyPath)
                sys.exit('Error: '+ dependencyPath + ' is a symlink to ' + realPath + '. Terminating operation.')

        for p in sections:
            dependencyPath = os.path.join(self.repositoryPath, p)
            if (recursive and not self.__isSymlink(dependencyPath)):
                d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)
                d.ensureNoSymlinkExistsInDependencySubtree('*', recursive)

    def __canCreateSymlink(self, path, section):
        dependencyKey = self.__getDependencyStoreKey(section)
        return (dependencyKey in GitDependenciesRepository.dependencyStore) and (os.path.normpath(path) != os.path.normpath(GitDependenciesRepository.dependencyStore[dependencyKey]))

    def __isSymlink(self, path):
        return os.path.exists(path) and os.path.islink(path)

    def __resolveSymlinkRealPath(self, path):
        return os.readlink(path) if os.path.islink(path) else path

    def __createSymlink(self, path, section):
        parentDir = os.path.abspath(os.path.join(path, os.pardir))
        if (not os.path.exists(parentDir)):
            os.mkdir(parentDir)
        dependencyKey = self.__getDependencyStoreKey(section)
        linkDir = GitDependenciesRepository.dependencyStore[dependencyKey]
        print("Dependency found for " + path + " in " + linkDir + ", creating symbolic link...")
        os.symlink(linkDir, path, True)

    def __updateSymlink(self, path, section):
        if (not self.__isSymlink(path)):
            return

        dependencyKey = self.__getDependencyStoreKey(section)
        linkDir = GitDependenciesRepository.dependencyStore[dependencyKey]
        print("Updating symbolic link " + path + " => " + linkDir)
        os.remove(path)
        os.symlink(linkDir, path, True)

    def __removeSymlink(self, path):
        if (self.__isSymlink(path)):
            print("Removing symbolic link " + path)
            os.remove(path)

    def __removeFromDependencyStore(self, key):
        try:
            del GitDependenciesRepository.dependencyStore[key]
        except KeyError:
            pass

    def __cleanPath(self, path):
        return path.rstrip('/')

    def __saveDependenciesFile(self):
        if (self.config == None):
            return

        with open(os.path.join(self.repositoryPath, GITDEPENDS_FILE), 'w') as configFile:
            self.config.write(configFile)

    def __loadDependenciesFile(self):
        if (not os.path.exists(self.repositoryPath)):
            return
        filePath = os.path.join(self.repositoryPath, GITDEPENDS_FILE)
        if (not os.path.exists(filePath)):
            return
        if (self.config != None):
            return
        # print ('Reading ' + filePath)
        self.config = configparser.ConfigParser()
        self.config.read(filePath)

        self.__updateDependencyStore()

    def __updateDependencyStore(self):
        sections = self.config.sections()
        for p in sections:
            dependencyPath = os.path.join(self.repositoryPath, p)
            if (not self.__isSymlink(dependencyPath)):
                key = self.__getDependencyStoreKey(p)
                if (key not in GitDependenciesRepository.dependencyStore):
                    GitDependenciesRepository.dependencyStore[key] = dependencyPath

    def __getDependencyStoreKey(self, section):
        if (self.config == None):
            return
        
        return self.config[section]['url']