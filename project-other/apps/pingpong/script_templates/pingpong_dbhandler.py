from dbhandler import DataBaseHandler  # noqa: D100, INP001


class PingPongDataBaseHandler(DataBaseHandler):
    """Database connection handler."""

    def _init_table(self) -> None:
        with self.conn.cursor() as cursor:
            cursor.execute(
                """
                CREATE TABLE {{.dbTableName}} (
                    id SERIAL PRIMARY KEY,
                    value INTEGER NOT NULL
                );
                """
            )
            cursor.execute(
                "INSERT INTO {{.dbTableName}} (id, value) VALUES ({{.dbCounterTableItemId}}, 0);"  # noqa: E501
            )
            self.conn.commit()

    def increment_counter_value(self) -> None:  # noqa: D102
        with self.conn.cursor() as cursor:
            cursor.execute(
                """
                UPDATE {{.dbTableName}}
                SET value = value + 1
                WHERE id = {{.dbCounterTableItemId}};
                """
            )
            self.conn.commit()

    def get_counter_value(self) -> int:  # noqa: D102
        with self.conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT value FROM {{.dbTableName}}
                WHERE id = {{.dbCounterTableItemId}};
                """
            )
            return cursor.fetchone()[0]
