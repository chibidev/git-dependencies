import configparser
import os
import os.path
import sys
import shutil

from cmdtask import Task

class GitRepository:
	def __init__(self, url = '', path = '.'):
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

	def clone(self, branch = None):
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

	def currentBranch(self, upstream = False):
		return self.revParse('HEAD', upstream, True)

	def currentSha(self):
		return self.revParse('HEAD')

	def commit(self, message, files = []):
		arguments = ['commit', '-m', message, '--'] + files
		self._runGitTask(arguments).output

	def revParse(self, rev, upstream = False, abbreviate = False):
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

	def _runGitTask(self, arguments, useConfig = True, exitOnError = True):
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
