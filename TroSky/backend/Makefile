.PHONY: help install dev-install run worker beat lint format typecheck test test-cov \
        migrate migrate-create migrate-downgrade seed seed-reference seed-demo simulate-gps docker-up docker-down docker-logs docker-build \
        precommit-install clean

PYTHON ?= python
PIP ?= pip

help:
	@echo "TroSky backend — common developer commands"
	@echo "  make install            Install runtime dependencies"
	@echo "  make dev-install        Install runtime + dev dependencies, register pre-commit hooks"
	@echo "  make run                Run the API locally with autoreload"
	@echo "  make worker             Run a Celery worker locally"
	@echo "  make beat               Run the Celery beat scheduler locally"
	@echo "  make lint               Run ruff check"
	@echo "  make format             Run ruff format"
	@echo "  make typecheck          Run mypy"
	@echo "  make test               Run the test suite"
	@echo "  make test-cov           Run tests with coverage (fails under 80%)"
	@echo "  make migrate            Apply all pending Alembic migrations"
	@echo "  make migrate-create m='message'   Autogenerate a new migration"
	@echo "  make migrate-downgrade  Downgrade one migration"
	@echo "  make seed               Load development seed data"
	@echo "  make seed-reference     Add missing roles/permissions (safe in production)"
	@echo "  make seed-demo          Load demo stops, routes, a week of trips and test accounts"
	@echo "  make simulate-gps       Drive a demo trip along its route (ARGS=\"--speedup 3\")"
	@echo "  make docker-up          Start the full local stack via docker compose"
	@echo "  make docker-down        Stop the local stack"
	@echo "  make docker-build       Build the production image"

install:
	$(PIP) install .

dev-install:
	$(PIP) install -e ".[dev]"
	pre-commit install

run:
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

worker:
	celery -A app.workers.celery_app worker --loglevel=info --concurrency=4

beat:
	celery -A app.workers.celery_app beat --loglevel=info

lint:
	ruff check .

format:
	ruff format .
	ruff check --fix .

typecheck:
	mypy app scripts

test:
	pytest

test-cov:
	pytest --cov=app --cov-report=term-missing --cov-report=xml --cov-fail-under=80

migrate:
	alembic upgrade head
	$(PYTHON) -m scripts.seed_reference_data

migrate-create:
	alembic revision --autogenerate -m "$(m)"

migrate-downgrade:
	alembic downgrade -1

seed:
	$(PYTHON) -m scripts.seed_dev_data

seed-reference:
	$(PYTHON) -m scripts.seed_reference_data

seed-demo:
	$(PYTHON) -m scripts.seed_demo_data

simulate-gps:
	$(PYTHON) -m scripts.simulate_gps $(ARGS)

docker-up:
	docker compose up --build

docker-down:
	docker compose down -v

docker-build:
	docker build -t trosky-backend:local --target runtime .

precommit-install:
	pre-commit install

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	rm -rf .pytest_cache .mypy_cache .ruff_cache htmlcov .coverage
