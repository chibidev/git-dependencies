import configparser
import os
import os.path
import sys
import shutil

from utils.cmdtask import Task
from utils.cmdtask import ShellTask

from git.repositories import GitRepository
from utils.changedir import ChangeDir
from git.os_types import generate_os_types
from git.dump import DumpType

GITDEPENDS_FILE = '.gitdepends'

class GitDependenciesRepository(GitRepository):
	dependencyStore = {}
	def __init__(self, url = '', path = '.'):
		super().__init__(url, path)

		self.config = None

		self.__loadDependenciesFile()
		# atexit.register(self.__saveDependenciesFile)

	def clone(self, branch = 'master'):
		super().clone(branch)
		self.__loadDependenciesFile()

	def checkout(self, ref):
		super().checkout(ref)
		self.config = None
		self.__loadDependenciesFile()

	def addDependency(self, url, path, ref = 'master'):
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

	def updateDependencies(self, path = '*', recursive = False, osFilter = [], overrides = None, override_all = False):
		if (self.config == None):
			return
		cleanPath = self.__cleanPath(path)
		if (cleanPath == '*'):
			sections = self.config.sections()
		else:
			sections = [cleanPath]
		for p in sections:
			# Continue with the next section, OS is filtered
			if (self.config.has_option(p, 'os')):
				filteredOSTypes = generate_os_types(self.config[p]['os'])
				if (len(osFilter) > 0 and len(set(filteredOSTypes).intersection(osFilter)) == 0):
					continue

			# If overrides are used, get the override. Fail for missing override if override_all is set.
			overrideRef = None
			if(overrides):
				overrideRef = overrides.get(self.config[p]['url'])
				if(override_all and not overrideRef):
					sys.exit('overrides incomplete, missing: {}'.format(self.config[p]['url']))

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
			if (not os.path.exists(dependencyPath) or not d.isValidRepository()):
				print(dependencyPath + ' was not found, cloning into dependency...')
				if (overrideRef):
					d.clone(branch = None)
					d.checkout(overrideRef)
				elif (self.config.has_option(p, 'freezed')):
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
				if (overrideRef):
					d.fetch('origin', overrideRef)
					d.checkout(overrideRef)
				elif (self.config.has_option(p, 'freezed')):
					d.fetch('origin', self.config[p]['freezed'])
					d.checkout(self.config[p]['ref'])
				else:
					d.fetch('origin', self.config[p]['ref'])
					d.checkout(self.config[p]['ref'])
					d.integrateChanges(self.config[p]['ref'])
				d.updateSubmodules(recursive)


		for p in sections:
			# Continue with the next section, OS is filtered
			if (self.config.has_option(p, 'os')):
				filteredOSTypes = generate_os_types(self.config[p]['os'])
				if (len(osFilter) > 0 and len(set(filteredOSTypes).intersection(osFilter)) == 0):
					continue

			dependencyPath = os.path.join(self.repositoryPath, p)
			if(recursive and not self.__isSymlink(dependencyPath)):
				d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)
				d.updateDependencies('*', recursive, [], overrides, override_all)

		for p in sections:
			# Continue with the next section, OS is filtered
			if (self.config.has_option(p, 'os')):
				filteredOSTypes = generate_os_types(self.config[p]['os'])
				if (len(osFilter) > 0 and len(set(filteredOSTypes).intersection(osFilter)) == 0):
					continue

			dependencyPath = os.path.join(self.repositoryPath, p)
			if(self.__isSymlink(dependencyPath)):
				dependencyPath = self.__resolveSymlinkRealPath(dependencyPath)

			d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)
			if self.config.has_option(p, 'command'):
				print("Run command on dependency ({})".format(p))
				with ChangeDir(self.repositoryPath):
					runCommand = self.config[p]['command']
					if (runCommand.startswith("!sh ")):
						task = ShellTask(runCommand[4:])
						task.run()
					else:
						task = Task('git')
						task.run(runCommand.split(' '))
					if (task.output != ''):
						print(task.output)
					if (task.exitCode() != 0):
						sys.exit(task.exitCode())

	def dumpDependency(self, path = '*', recursive = False, dump_type = DumpType.Default, customString = ""):
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
				continue

			d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)
			if (self.config.has_option(p, 'freezed')):
				branch = self.config[p]['freezed']
				upstream = d.revParse(self.config[p]['freezed'], upstream = True, abbreviate = True)
			else:
				branch = d.currentBranch(upstream = False)
				upstream = d.currentBranch(upstream = True)
			hash = d.currentSha()

			if (dump_type == DumpType.Default):
				print('Dependency ' + p + ' following ' + branch + ' (tracking: ' + upstream + ') is now at rev ' + hash)
			elif (dump_type == DumpType.Header):
				sanitizedPath = p.replace('/', '_').replace(' ', '_').replace('-', '_').upper()
				print('#define ' + sanitizedPath + '_BRANCH "' + branch + '"')
				print('#define ' + sanitizedPath + '_REMOTE "' + upstream + '"')
				print('#define ' + sanitizedPath + '_HASH "' + hash + '"')
				print('')
			elif (dump_type == DumpType.Custom):
				dependencyName = p.split('/')[-1]
				log = customString
				log = log.replace("%dependencyName%", dependencyName)
				log = log.replace("%dependency%", p)
				log = log.replace("%branch%", branch)
				log = log.replace("%remoteBranch%", upstream)
				log = log.replace("%sha1%", hash)
				sanitizedName = dependencyName.replace('/', '_').replace(' ', '_').replace('-', '_').upper()
				log = log.replace("%sanitizedName%", sanitizedName)
				sanitizedPath = p.replace('/', '_').replace(' ', '_').replace('-', '_').upper()
				log = log.replace("%sanitizedPath%", sanitizedPath)
				print(log)

			if (recursive):
				d.dumpDependency('*', recursive, dump_type, customString)

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
			sys.exit(p + ' is a symlink to ' + realPath + '. Terminating operation.')

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

	def freezeDependency(self, path = '*', recursive = False):
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

	def unfreezeDependency(self, path = '*', recursive = False):
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

	def foreachDependency(self, command, recursive = False):
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

	def command(self, path, command):
		if (self.config == None):
			return

		p = self.__cleanPath(path)

		if command and len(command) > 0:
			self.config[p]['command'] = "{}".format(command)
		else:
			self.config.remove_option(p, 'command')

		self.__saveDependenciesFile()

	def ensureNoSymlinkExistsInDependencySubtree(self, path = '*', recursive = False):
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
				sys.exit('Error: ' + dependencyPath + ' is a symlink to ' + realPath + '. Terminating operation.')

		for p in sections:
			dependencyPath = os.path.join(self.repositoryPath, p)
			if (recursive and not self.__isSymlink(dependencyPath)):
				d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)
				d.ensureNoSymlinkExistsInDependencySubtree('*', recursive)

	def setOSFilter(self, path, osFilter):
		if (self.config == None):
			return
		p = self.__cleanPath(path)
		if (len(osFilter) > 0):
			self.config[p]['os'] = ','.join(osFilter)
		else:
			self.config.remove_option(p, 'os')
		self.__saveDependenciesFile()

	def dumpDeps(self, depStore, path = '*', recursive = False):
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
				continue

			url = self.config[p]['url']
			existingHash = depStore.get(url)
			d = GitDependenciesRepository(url, dependencyPath)
			hash = d.currentSha()

			if(existingHash is not None and hash != existingHash):
				# Same repo checked out at a different commits? Something is wrong here, bail out.
				sys.exit('Inconsistent dependency tree (repo {})'.format(url))

			depStore[url] = hash

			if (recursive):
				d.dumpDeps(depStore, '*', recursive)

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
