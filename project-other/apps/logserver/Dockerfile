FROM python:3.11-slim AS logserver

FROM python:3.11 AS printer

WORKDIR /tmp

COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
