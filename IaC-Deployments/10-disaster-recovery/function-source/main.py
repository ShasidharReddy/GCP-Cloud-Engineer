import json
import os
from flask import Request


def orchestrate(request: Request):
    payload = {
        "project_id": os.environ.get("PROJECT_ID"),
        "primary_instance": os.environ.get("PRIMARY_INSTANCE"),
        "replica_instance": os.environ.get("REPLICA_INSTANCE"),
        "message": "DR helper invoked. Integrate Cloud SQL promotion, snapshot restore, and notification workflows here.",
    }
    return (json.dumps(payload), 200, {"Content-Type": "application/json"})
