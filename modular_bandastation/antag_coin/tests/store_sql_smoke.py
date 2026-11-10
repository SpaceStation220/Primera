"""Exercise the actual DM SQL against a disposable local MariaDB container.

Start a container named codex-antag-coin-db with an empty antag_coin_test database.
This script only connects to that container and that dedicated database.
"""

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import os
import re
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[3]
STORE = (Path(__file__).resolve().parents[1] / "code/store.dm").read_text()
QUERIES = re.findall(r'NewQuery\(\{"(.*?)"\}', STORE, re.S)
assert len(QUERIES) == 5, "Review SQL extraction after changing store.dm"
RECOVER, READ, INSERT, CLAIM, RESOLVE = QUERIES
DOCKER = ["docker", "--host=unix:///var/run/docker.sock", "exec", "-i",
          "codex-antag-coin-db", "mariadb", "-uroot", "--batch",
          "--skip-column-names", "antag_coin_test"]
ENV = {key: value for key, value in os.environ.items() if key not in {
    "DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_TLS", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH"
}}


def execute(sql):
    result = subprocess.run(DOCKER, input=sql, text=True, capture_output=True,
                            check=True, env=ENV)
    return [line.split("\t") for line in result.stdout.splitlines()]


def literal(value):
    if isinstance(value, (int, bool)):
        return str(int(value))
    return "'" + str(value).replace("\\", "\\\\").replace("'", "''") + "'"


def query(source, **params):
    sql = re.sub(r'\[format_table_name\("([a-z_]+)"\)\]', r'`\1`', source)
    return re.sub(r':([a-z_]+)', lambda match: literal(params[match[1]]), sql)


class StoreSQL(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        execute("""
            DROP TABLE IF EXISTS antag_coin_accounts, schema_revision_220, `round`;
            CREATE TABLE schema_revision_220 (major INT, minor INT);
            CREATE TABLE `round` (id INT PRIMARY KEY, start_datetime DATETIME);
            INSERT INTO `round` VALUES (1,NULL),(2,NOW()),(3,NULL);
        """)
        execute((ROOT / "SQL/bandastation/antag_coin.sql").read_text())

    def setUp(self):
        execute("DELETE FROM antag_coin_accounts;")
        execute(query(INSERT, ckey="player") + ";")

    def claim(self, token="first", server="test:1", game_round=3):
        rows = execute(query(CLAIM, ckey="player", cooldown=604800,
                             request_id=token, server_id=server, round_id=game_round)
                       + "; SELECT ROW_COUNT();")
        return int(rows[-1][0])

    def resolve(self, token="first", refund=True):
        return execute(query(RESOLVE, ckey="player", request_id=token,
                             refund=refund, state="refunded" if refund else "used")
                       + "; SELECT ROW_COUNT();")[-1][0]

    def state(self):
        return execute(query(READ, ckey="player") + ";")[0]

    def test_first_use_and_no_unsigned_underflow(self):
        self.assertEqual(self.state()[0:2], ["0", "unused"])
        self.assertEqual(self.claim(), 1)
        self.assertTrue(0 < int(self.state()[0]) <= 604800)
        self.assertEqual(execute("SELECT next_available-approved_at FROM antag_coin_accounts;")[0], ["604800"])
        self.assertEqual(self.state()[1], "pending")

    def test_concurrent_claims_have_one_winner(self):
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(self.claim, ["first", "second"]))
        self.assertEqual(sorted(results), [0, 1])

    def test_refund_is_idempotent_and_restores_prior_deadline(self):
        execute("UPDATE antag_coin_accounts SET next_available=12345;")
        self.assertEqual(self.claim(), 1)
        self.assertEqual(self.resolve(), "1")
        self.assertEqual(self.resolve(), "0")
        self.assertEqual(self.state()[0:2], ["0", "refunded"])
        self.assertEqual(execute("SELECT next_available FROM antag_coin_accounts;")[0], ["12345"])

    def test_wrong_or_old_request_cannot_refund_new_charge(self):
        self.claim("new")
        self.assertEqual(self.resolve("old"), "0")
        self.assertEqual(self.state()[1:3], ["pending", "new"])

    def test_commit_keeps_cooldown_and_refund_cannot_undo_it(self):
        self.claim()
        self.assertEqual(self.resolve(refund=False), "1")
        self.assertEqual(self.resolve(refund=True), "0")
        self.assertEqual(self.state()[1], "used")
        self.assertGreater(int(self.state()[0]), 0)
        self.assertEqual(self.claim("second"), 0)

    def test_elapsed_time_does_not_accumulate_credits(self):
        self.claim()
        self.resolve(refund=False)
        execute("UPDATE antag_coin_accounts SET next_available=UNIX_TIMESTAMP()-1209600;")
        self.assertEqual(self.claim("second"), 1)
        self.assertEqual(self.claim("third"), 0)

    def test_pending_operation_blocks_even_after_deadline(self):
        self.claim()
        execute("UPDATE antag_coin_accounts SET next_available=0;")
        self.assertEqual(self.claim("second"), 0)

    def test_recovery_refunds_unstarted_round_only_on_same_server(self):
        self.claim(game_round=1)
        execute(query(RECOVER, server_id="different", round_id=3) + ";")
        self.assertEqual(self.state()[1], "pending")
        execute(query(RECOVER, server_id="test:1", round_id=3) + ";")
        self.assertEqual(self.state()[0:2], ["0", "refunded"])

    def test_recovery_retains_charge_for_started_round(self):
        self.claim(game_round=2)
        execute(query(RECOVER, server_id="test:1", round_id=3) + ";")
        self.assertEqual(self.state()[1], "used")
        self.assertGreater(int(self.state()[0]), 0)

    def test_recovery_does_not_touch_current_process(self):
        self.claim(game_round=3)
        execute(query(RECOVER, server_id="test:1", round_id=3) + ";")
        self.assertEqual(self.state()[1], "pending")


if __name__ == "__main__":
    unittest.main(verbosity=2)
