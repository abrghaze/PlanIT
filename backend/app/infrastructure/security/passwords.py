from __future__ import annotations

from argon2 import PasswordHasher, Type
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError

_HASHER = PasswordHasher(
    time_cost=3,
    memory_cost=65536,
    parallelism=4,
    hash_len=32,
    salt_len=16,
    type=Type.ID,
)
_DUMMY_HASH = _HASHER.hash("PlanIT constant-time missing-user password probe")


class PasswordService:
    """Argon2id password hashing with a timing probe for unknown identities."""

    def hash(self, password: str) -> str:
        return _HASHER.hash(password)

    def verify(self, password_hash: str | None, password: str) -> bool:
        candidate = password_hash or _DUMMY_HASH
        try:
            matches = _HASHER.verify(candidate, password)
        except (InvalidHashError, VerificationError, VerifyMismatchError):
            return False
        return bool(matches) and password_hash is not None

    def needs_rehash(self, password_hash: str) -> bool:
        try:
            return _HASHER.check_needs_rehash(password_hash)
        except InvalidHashError:
            return True
