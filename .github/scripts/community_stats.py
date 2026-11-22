"""Prints the app-wide totals for the Settings support card as JSON.

Run daily by .github/workflows/community_stats.yml, which publishes the output
on the `stats` branch for CommunityStatsService to download.

Each install that shares usage statistics keeps one Firestore document,
installs/{uid} = {books, minutes, updated, expires} (see
LibrarySnapshotService). Installs whose document was updated in the last
ACTIVE_DAYS count:

  readers         how many such installs there are
  books_tracked   the sum of their library sizes
  hours_read      the sum of their reading-session minutes, in whole hours

These are exact sums of current libraries, computed by Firestore itself.

It also deletes documents past their `expires` time (90 days after an install
last sent). Firestore's TTL policies would do this, but they need billing
enabled, and the project is on the free Spark plan.

Environment: FIREBASE_CREDENTIALS, the JSON key of a service account with the
Cloud Datastore User role on the Firebase project (read and delete).
"""

import json
import os
import sys
from datetime import datetime, timedelta, timezone

from google.cloud import firestore
from google.cloud.firestore_v1 import aggregation
from google.cloud.firestore_v1.base_query import FieldFilter
from google.oauth2 import service_account

# Apps re-send at least weekly; a quarter of silence means the install is gone.
ACTIVE_DAYS = 90

# Firestore's limit on writes per batch.
BATCH_SIZE = 500


def delete_expired(db: firestore.Client) -> int:
    """Deletes installs whose `expires` has passed; returns how many."""
    now = datetime.now(timezone.utc)
    expired = (
        db.collection("installs")
        .where(filter=FieldFilter("expires", "<", now))
        .select([])
    )
    deleted = 0
    batch = db.batch()
    for doc in expired.stream():
        batch.delete(doc.reference)
        deleted += 1
        if deleted % BATCH_SIZE == 0:
            batch.commit()
            batch = db.batch()
    if deleted % BATCH_SIZE:
        batch.commit()
    return deleted


def main() -> None:
    info = json.loads(os.environ["FIREBASE_CREDENTIALS"])
    db = firestore.Client(
        project=info["project_id"],
        credentials=service_account.Credentials.from_service_account_info(info),
    )

    deleted = delete_expired(db)
    print(f"Deleted {deleted} expired installs", file=sys.stderr)

    cutoff = datetime.now(timezone.utc) - timedelta(days=ACTIVE_DAYS)
    active = db.collection("installs").where(
        filter=FieldFilter("updated", ">=", cutoff)
    )
    query = aggregation.AggregationQuery(active)
    query.count(alias="readers")
    query.sum("books", alias="books")
    query.sum("minutes", alias="minutes")

    totals = {r.alias: int(r.value or 0) for batch in query.get() for r in batch}

    print(
        json.dumps(
            {
                "readers": totals.get("readers", 0),
                "books_tracked": totals.get("books", 0),
                "hours_read": totals.get("minutes", 0) // 60,
                "updated": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
