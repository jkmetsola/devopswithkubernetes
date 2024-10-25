"""Provides the BackendDatabaseHandler class."""  # noqa: INP001

from dbhandler import DataBaseHandler


class BackendDatabaseHandler(DataBaseHandler):  # noqa: D101
    def _init_table(self) -> None:
        with self.conn.cursor() as cursor:
            cursor.execute(
                """
                CREATE TABLE {{.dbTableName}} (
                    id SERIAL PRIMARY KEY,
                    value TEXT NOT NULL
                );
                """
            )
            self.conn.commit()

    def insert_todo(self, todo: str) -> None:  # noqa: D102
        with self.conn.cursor() as cursor:
            cursor.execute("INSERT INTO {{.dbTableName}} (value) VALUES (%s);", (todo,))
            self.conn.commit()

    def get_todos(self) -> list:  # noqa: D102
        with self.conn.cursor() as cursor:
            cursor.execute("SELECT value FROM {{.dbTableName}};")
            return [item[0] for item in cursor.fetchall()]
