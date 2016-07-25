import configparser
import os
import os.path
import sys

from cmdtask import Task
from cmdtask import ShellTask

from git.repositories import GitRepository
from git.utilities import ChangeDir

GITDEPENDS_FILE = '.gitdepends'

class GitDependenciesRepository(GitRepository):
	def __init__(self, url='', path = '.'):
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

	def updateDependencies(self, path = '*', recursive = False):
		if (self.config == None):
			return
		cleanPath = self.__cleanPath(path)
		if (cleanPath == '*'):
			sections = self.config.sections()
		else:
			sections = [cleanPath]
		for p in sections:
			dependencyPath = os.path.join(self.repositoryPath, p)
			d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)
			if (not os.path.exists(dependencyPath)):
				print (dependencyPath + ' was not found, cloning into dependency...')
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

				print ('Updating ' + dependencyPath)
				if (self.config.has_option(p, 'freezed')):
					d.fetch('origin', self.config[p]['freezed'])
					d.checkout(self.config[p]['ref'])
				else:
					d.fetch('origin', self.config[p]['ref'])
					d.checkout(self.config[p]['ref'])
					d.integrateChanges(self.config[p]['ref'])
				d.updateSubmodules(recursive)

			if self.config.has_option(p, 'command'):
				command = self.config[p]['command']
				print('Run command: ' + command)
				task = ShellTask(command[4:])
				task.run()
				if (task.output != ''):
					print(task.output, file=sys.stderr)

			d.__loadDependenciesFile()

			if (recursive):
				d.updateDependencies('*', recursive)

	def dumpDependency(self, path = '*', recursive = False, dumpHeader = False):
		if (self.config == None):
			return
		cleanPath = self.__cleanPath(path)
		if (cleanPath == '*'):
			sections = self.config.sections()
		else:
			sections = [cleanPath]
		for p in sections:
			d = GitDependenciesRepository(self.config[p]['url'], os.path.join(self.repositoryPath, p))
			if (self.config.has_option(p, 'freezed')):
				branch = self.config[p]['freezed']
				upstream = d.revParse(self.config[p]['freezed'], upstream = True, abbreviate = True)
			else:
				branch = d.currentBranch(upstream = False)
				upstream = d.currentBranch(upstream = True)
			hash = d.currentSha()

			if (not dumpHeader):
				print ('Dependency ' + p + ' following ' + branch + ' (tracking: ' + upstream + ') is now at rev ' + hash)
			else:
				sanitizedPath = p.replace('/', '_').replace(' ', '_').replace('-', '_').upper();
				print ('#define ' + sanitizedPath + '_BRANCH "' + branch + '"')
				print ('#define ' + sanitizedPath + '_REMOTE "' + upstream + '"')
				print ('#define ' + sanitizedPath + '_HASH "' + hash + '"')
				print ('')
			if (recursive):
				d.dumpDependency('*', recursive, dumpHeader)

	def setDependency(self, path, ref):
		if (self.config == None):
			return
		if (path == '' or ref == ''):
			print ('Usage: set <path> <ref>')
			return

		p = self.__cleanPath(path)
		if (self.config.has_section(p) != True):
			print ('Path cannot be found in gitdepends: ' + p)
			return

		self.updateDependencies(path)

		dependencyPath = os.path.join(self.repositoryPath, p)
		d = GitDependenciesRepository(self.config[p]['url'], dependencyPath)

		refIsInRemote = ref.find('origin/') == 0

		if (refIsInRemote):
			if (not d.isRefValid(ref)):
				print ('Error: unknown ref: ' + ref)
				return
		else:
			if (not d.isRefValid(ref)):
				print ('Warning: ref is invalid: ' + ref + '. Checking remote')
				remoteRef = 'origin/' + ref
				if (not d.isRefValid(remoteRef)):
					print ('Error: unknown ref: ' + ref)
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
			d = GitDependenciesRepository(self.config[p]['url'], os.path.join(self.repositoryPath, p))
			with ChangeDir(d.repositoryPath):
				task.run(runCommand.split(' '))
				if (task.output != ''):
					print(task.output, file=sys.stderr)
				if (task.exitCode() != 0):
					sys.exit(task.exitCode())

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
