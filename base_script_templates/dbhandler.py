"""Provides a handler for database connections using psycopg2."""  # noqa: INP001

import os

import psycopg2


class DatabaseHandler:
    """Database connection handler."""

    def __init__(self) -> None:
        """Initialise database connection."""
        self.conn = psycopg2.connect(
            host="{{.databases.postgres.serviceName}}",
            port="{{.databases.postgres.appPort}}",
            dbname="{{index .databases.postgres.containerNames 0}}",
            user="{{index .databases.postgres.containerNames 0}}",
            password=os.environ["POSTGRES_PASSWORD"],
        )
        if not self._table():
            self._init_table()

    def _table(self) -> bool:
        with self.conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT *
                FROM INFORMATION_SCHEMA.TABLES
                WHERE TABLE_NAME = '{{.dbTableName}}';
                """
            )
            return cursor.fetchone()
