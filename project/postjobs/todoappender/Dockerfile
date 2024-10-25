FROM python:3.11 AS todoappender

WORKDIR /tmp

COPY requirements-dbhandler.txt requirements-dbhandler.txt
COPY requirements-requests.txt requirements-requests.txt
RUN pip install --no-cache-dir -r requirements-dbhandler.txt && \
    pip install --no-cache-dir -r requirements-requests.txt
