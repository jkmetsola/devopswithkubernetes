FROM python:3.11 AS backend

WORKDIR /tmp

COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

FROM backend AS backend-debug

RUN pip install --no-cache-dir debugpy==1.8.6
