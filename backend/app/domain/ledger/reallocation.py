from __future__ import annotations

import hashlib
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from uuid import UUID

from app.domain.errors import DomainError
from app.domain.money import Money


@dataclass(frozen=True, slots=True)
class AccountPosition:
    account_id: UUID
    balance: Money
    allow_negative: bool
    version: int


@dataclass(frozen=True, slots=True)
class ReallocationLine:
    account_id: UUID
    before: Money
    target: Money
    delta: Money


@dataclass(frozen=True, slots=True)
class ReallocationPreview:
    fixed_total: Money
    balancing_account_id: UUID
    lines: tuple[ReallocationLine, ...]
    source_fingerprint: str


def preview_reallocation(
    *,
    positions: Sequence[AccountPosition],
    fixed_total: Money,
    balancing_account_id: UUID,
    requested_balances: Mapping[UUID, Money],
) -> ReallocationPreview:
    if len(positions) < 2:
        raise DomainError(
            "REALLOCATION_REQUIRES_MULTIPLE_ACCOUNTS",
            "Reallocation requires at least two accounts.",
        )

    by_id = {position.account_id: position for position in positions}
    if len(by_id) != len(positions):
        raise DomainError("DUPLICATE_ACCOUNT", "Each reallocation account must be unique.")
    if balancing_account_id not in by_id:
        raise DomainError("BALANCING_ACCOUNT_REQUIRED", "Balancing account is not selected.")
    if balancing_account_id in requested_balances:
        raise DomainError(
            "BALANCING_ACCOUNT_IS_DERIVED",
            "The balancing account cannot have a manually requested balance.",
        )
    unknown_ids = set(requested_balances) - set(by_id)
    if unknown_ids:
        raise DomainError(
            "UNAUTHORIZED_ENTITY",
            "A requested account is not part of this reallocation.",
        )

    for position in positions:
        if position.balance.currency != fixed_total.currency:
            raise DomainError(
                "CURRENCY_MISMATCH",
                "V1 reallocation supports same-currency accounts only.",
            )
    for requested in requested_balances.values():
        if requested.currency != fixed_total.currency:
            raise DomainError(
                "CURRENCY_MISMATCH",
                "V1 reallocation supports same-currency accounts only.",
            )

    current_total = Money.zero(fixed_total.currency)
    for position in positions:
        current_total += position.balance
    if current_total != fixed_total:
        raise DomainError(
            "STALE_BALANCE",
            "The captured fixed total no longer matches current account balances.",
            details={
                "captured_total": fixed_total.to_api(),
                "current_total": current_total.to_api(),
            },
        )

    targets: dict[UUID, Money] = {}
    non_balancing_total = Money.zero(fixed_total.currency)
    for position in positions:
        if position.account_id == balancing_account_id:
            continue
        target = requested_balances.get(position.account_id, position.balance)
        targets[position.account_id] = target
        non_balancing_total += target
    targets[balancing_account_id] = fixed_total - non_balancing_total

    lines: list[ReallocationLine] = []
    for position in positions:
        target = targets[position.account_id]
        if target.amount < 0 and not position.allow_negative:
            raise DomainError(
                "NEGATIVE_BALANCE_NOT_ALLOWED",
                "Reallocation would create a disallowed negative balance.",
                details={"account_id": str(position.account_id)},
            )
        lines.append(
            ReallocationLine(
                account_id=position.account_id,
                before=position.balance,
                target=target,
                delta=target - position.balance,
            )
        )

    fingerprint_source = "|".join(
        f"{position.account_id}:{position.version}:{position.balance.to_api()}"
        for position in sorted(positions, key=lambda value: str(value.account_id))
    )
    return ReallocationPreview(
        fixed_total=fixed_total,
        balancing_account_id=balancing_account_id,
        lines=tuple(lines),
        source_fingerprint=hashlib.sha256(fingerprint_source.encode()).hexdigest(),
    )
