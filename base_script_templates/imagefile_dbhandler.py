"""Provides a handler for image file database operations."""  # noqa: INP001

import psycopg2
from dbhandler import DatabaseHandler


class ImageFileDatabaseHandler(DatabaseHandler):  # noqa: D101
    def _init_table(self) -> None:
        with self.conn.cursor() as cursor:
            cursor.execute(
                """
                CREATE TABLE {{.dbTableName}} (
                    id SERIAL PRIMARY KEY,
                    data BYTEA
                );
                """
            )
            cursor.execute(
                "INSERT INTO {{.dbTableName}} (id, data) VALUES ({{.dbItemId}}, %s);",
                (psycopg2.Binary(b""),),
            )
        self.conn.commit()

    def update_imagefile(self, imagefile_bytes: bytes) -> None:  # noqa: D102
        with self.conn.cursor() as cursor:
            cursor.execute(
                """
                UPDATE {{.dbTableName}}
                SET data = %s
                WHERE id = {{.dbItemId}};
                """,
                (psycopg2.Binary(imagefile_bytes),),
            )
        self.conn.commit()

    def get_imagefile(self) -> list:  # noqa: D102
        with self.conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT data FROM {{.dbTableName}}
                WHERE id = {{.dbItemId}};
                """
            )
            return cursor.fetchone()[0]
