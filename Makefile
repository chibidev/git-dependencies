init:
	python3 -m pip install -r requirements-dev.txt

test-unit:
	python3 -m pytest --capture=sys -v -s

test-integration:
	./tests/integration/test.sh

test: clean test-unit test-integration

clean:
	find . -name "*.pyc" -print -delete
	find . -name "__pycache__" -print -delete
