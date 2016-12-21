
class Unbuffered(object):
	def __init__(self, stream):
		self.stream = stream
	def write(self, data):
		self.stream.write(data.encode('utf-8').decode('utf-8'))
		self.stream.flush()
	def __getattr__(self, attr):
		return getattr(self.stream, attr)
