.PHONY: init
init:
	pip install --upgrade pip pre-commit
	pre-commit install
