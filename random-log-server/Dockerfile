FROM python:3.11-slim AS random-string-printer

WORKDIR /app
COPY . /app

CMD ["./run_random_string_printer.sh"]

FROM random-string-printer AS random-log-server

CMD ["./run_log_server.sh"]
