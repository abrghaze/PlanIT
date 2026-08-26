from __future__ import annotations

from dataclasses import dataclass
from decimal import ROUND_HALF_EVEN, Decimal, localcontext
from uuid import UUID

from app.domain.errors import DomainError
from app.domain.ledger.reallocation import AccountPosition, fingerprint_positions
from app.domain.money import Money

_FX_SCALE = Decimal("0.000000000001")
_MAX_FX_RATE = Decimal("999999999999999999.999999999999")


@dataclass(frozen=True, slots=True)
class TransferFee:
    account_id: UUID
    amount: Money


@dataclass(frozen=True, slots=True)
class TransferAccountImpact:
    account_id: UUID
    before: Money
    delta: Money
    after: Money
    version: int


@dataclass(frozen=True, slots=True)
class TransferPreview:
    source_account_id: UUID
    destination_account_id: UUID
    source_amount: Money
    destination_amount: Money
    fx_rate: Decimal | None
    fee: TransferFee | None
    impacts: tuple[TransferAccountImpact, ...]
    source_fingerprint: str


def normalize_fx_rate(value: Decimal | None) -> Decimal | None:
    if value is None:
        return None
    if not isinstance(value, Decimal) or not value.is_finite():
        raise DomainError("INVALID_FX_RATE", "FX rate must be a finite decimal value.")
    exponent = value.as_tuple().exponent
    if not isinstance(exponent, int) or exponent < -12:
        raise DomainError(
            "FX_RATE_PRECISION_EXCEEDED",
            "FX rate may contain at most twelve fractional digits.",
        )
    if value <= 0 or value > _MAX_FX_RATE:
        raise DomainError("INVALID_FX_RATE", "FX rate must be greater than zero and in range.")
    with localcontext() as context:
        context.prec = 64
        normalized = value.quantize(_FX_SCALE, rounding=ROUND_HALF_EVEN)
    return normalized


def preview_transfer(
    *,
    positions: tuple[AccountPosition, ...],
    source_account_id: UUID,
    destination_account_id: UUID,
    source_amount: Money,
    destination_amount: Money | None,
    fx_rate: Decimal | None,
    fee: TransferFee | None,
) -> TransferPreview:
    if source_account_id == destination_account_id:
        raise DomainError(
            "SAME_TRANSFER_ACCOUNT",
            "Source and destination accounts must be different.",
        )
    source_amount.require_positive()
    by_id = {position.account_id: position for position in positions}
    if len(by_id) != len(positions):
        raise DomainError("DUPLICATE_ACCOUNT", "Each transfer account must be unique.")
    required_ids = {source_account_id, destination_account_id}
    if fee is not None:
        fee.amount.require_positive()
        required_ids.add(fee.account_id)
    if set(by_id) != required_ids:
        raise DomainError("UNAUTHORIZED_ENTITY", "A transfer account was not found.")

    source = by_id[source_account_id]
    destination = by_id[destination_account_id]
    if source.balance.currency != source_amount.currency:
        raise DomainError(
            "CURRENCY_MISMATCH",
            "Source amount must use the source account currency.",
        )

    normalized_rate = normalize_fx_rate(fx_rate)
    if source.balance.currency == destination.balance.currency:
        resolved_destination = destination_amount or source_amount
        if resolved_destination.currency != destination.balance.currency:
            raise DomainError(
                "CURRENCY_MISMATCH",
                "Destination amount must use the destination account currency.",
            )
        resolved_destination.require_positive()
        if normalized_rate is not None or resolved_destination.amount != source_amount.amount:
            raise DomainError(
                "CURRENCY_MISMATCH",
                "Same-currency transfers must move equal amounts without an FX rate.",
            )
    else:
        if destination_amount is None or normalized_rate is None:
            raise DomainError(
                "CURRENCY_MISMATCH",
                "Cross-currency transfers require destination amount and explicit FX rate.",
            )
        if destination_amount.currency != destination.balance.currency:
            raise DomainError(
                "CURRENCY_MISMATCH",
                "Destination amount must use the destination account currency.",
            )
        destination_amount.require_positive()
        with localcontext() as context:
            context.prec = 64
            expected = (source_amount.amount * normalized_rate).quantize(
                Money.SCALE,
                rounding=ROUND_HALF_EVEN,
            )
        if destination_amount.amount != expected:
            raise DomainError(
                "FX_AMOUNT_MISMATCH",
                "Destination amount must equal source amount multiplied by the FX rate.",
                details={"expected_destination_amount": format(expected, ".4f")},
            )
        resolved_destination = destination_amount

    if fee is not None and by_id[fee.account_id].balance.currency != fee.amount.currency:
        raise DomainError(
            "CURRENCY_MISMATCH",
            "Transfer fee must use the selected fee account currency.",
        )

    deltas = {position.account_id: Money.zero(position.balance.currency) for position in positions}
    deltas[source_account_id] -= source_amount
    deltas[destination_account_id] += resolved_destination
    if fee is not None:
        deltas[fee.account_id] -= fee.amount

    impacts: list[TransferAccountImpact] = []
    for position in positions:
        delta = deltas[position.account_id]
        after = position.balance + delta
        if after.amount < 0 and not position.allow_negative:
            raise DomainError(
                "NEGATIVE_BALANCE_NOT_ALLOWED",
                "Transfer would create a disallowed negative balance.",
                details={
                    "account_id": str(position.account_id),
                    "current_balance": position.balance.to_api(),
                    "projected_balance": after.to_api(),
                },
            )
        impacts.append(
            TransferAccountImpact(
                account_id=position.account_id,
                before=position.balance,
                delta=delta,
                after=after,
                version=position.version,
            )
        )

    return TransferPreview(
        source_account_id=source_account_id,
        destination_account_id=destination_account_id,
        source_amount=source_amount,
        destination_amount=resolved_destination,
        fx_rate=normalized_rate,
        fee=fee,
        impacts=tuple(impacts),
        source_fingerprint=fingerprint_positions(positions),
    )
