import subprocess
import os
import sys

class Task:
	def __init__(self, command):
		self.command = command

	def run(self, arguments = []):
		proc = subprocess.Popen([self.command] + arguments, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
		self.output = proc.stdout.read().decode("utf-8").strip()
		proc.wait()
		self.rc = proc.returncode;
		return self

	def exitCode(self):
		return self.rc

class ShellTask(Task):
	def __init__(self, command):
		super().__init__(command = command)
		self.output = ""
		self.rc = 0

	def run(self):
		try:
			self.output = subprocess.check_output(self.command, shell=True).decode("utf-8").strip()
		except subprocess.CalledProcessError as exp:
			self.rc = exp.returncode
