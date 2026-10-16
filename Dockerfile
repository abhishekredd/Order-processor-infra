FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=/app/src
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src ./src
COPY contracts ./contracts
RUN useradd -r app && chown -R app /app
USER app
# Cloud Run injects $PORT. One worker + threads keeps memory low; timeout 0 lets Cloud Run enforce its own.
CMD exec gunicorn --bind :${PORT:-8080} --workers 1 --threads 8 --timeout 0 "retailhub_order.app:create_app()"
