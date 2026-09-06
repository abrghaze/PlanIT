from __future__ import annotations

import argparse
import asyncio
from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import select

from app.application.planning import PlanningService
from app.core.config import get_settings
from app.db.models.planning import RecurringRuleModel
from app.db.session import create_db_engine, create_session_factory


async def process_due_once(*, user_limit: int = 100, rule_limit: int = 100) -> int:
    """Process one bounded batch; safe for cron and overlapping worker instances."""
    engine = create_db_engine(get_settings())
    session_factory = create_session_factory(engine)
    processed = 0
    try:
        async with session_factory() as session, session.begin():
            user_ids = list(
                (
                    await session.scalars(
                        select(RecurringRuleModel.user_id)
                        .where(
                            RecurringRuleModel.status == "ACTIVE",
                            RecurringRuleModel.next_due_at <= datetime.now(UTC),
                        )
                        .distinct()
                        .order_by(RecurringRuleModel.user_id)
                        .limit(user_limit)
                    )
                ).all()
            )
            for user_id in user_ids:
                occurrences = await PlanningService(session).process_due_in_transaction(
                    user_id=UUID(str(user_id)),
                    now=datetime.now(UTC),
                    limit=rule_limit,
                    request_id="recurring-worker",
                )
                processed += len(occurrences)
    finally:
        await engine.dispose()
    return processed


async def process_due_forever(
    *, interval_seconds: int, user_limit: int = 100, rule_limit: int = 100
) -> None:
    """Continuously process bounded batches for a long-running deployment worker."""
    while True:
        await process_due_once(user_limit=user_limit, rule_limit=rule_limit)
        await asyncio.sleep(interval_seconds)


def main() -> None:
    parser = argparse.ArgumentParser(description="Process due PlanIT recurring rules once.")
    parser.add_argument("--user-limit", type=int, default=100)
    parser.add_argument("--rule-limit", type=int, default=100)
    parser.add_argument(
        "--interval-seconds",
        type=int,
        help="Keep running and wait this many seconds between batches.",
    )
    args = parser.parse_args()
    if not 1 <= args.user_limit <= 10_000 or not 1 <= args.rule_limit <= 1_000:
        parser.error("Limits must be positive and bounded.")
    if args.interval_seconds is not None and not 30 <= args.interval_seconds <= 86_400:
        parser.error("Interval must be between 30 seconds and 24 hours.")
    if args.interval_seconds is None:
        asyncio.run(process_due_once(user_limit=args.user_limit, rule_limit=args.rule_limit))
    else:
        asyncio.run(
            process_due_forever(
                interval_seconds=args.interval_seconds,
                user_limit=args.user_limit,
                rule_limit=args.rule_limit,
            )
        )


if __name__ == "__main__":
    main()
