import subprocess

class Task:
	def __init__(self, command):
		self.command = command
	
	def run(self, arguments):
		proc = subprocess.Popen([self.command] + arguments, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
		self.output = proc.stdout.read().decode("utf-8").strip()
		proc.wait()
		self.rc = proc.returncode;
		return self
	
	def exitCode(self):
		return self.rc