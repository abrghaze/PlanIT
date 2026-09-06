from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class DeleteProfileRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    password: str = Field(strict=True, min_length=1, max_length=128)
    confirmation: Literal["DELETE MY PLANIT DATA"]


class RestoreBackupRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    password: str = Field(strict=True, min_length=1, max_length=128)
    confirmation: Literal["RESTORE MY PLANIT DATA"]
    backup: dict[str, object]


class RestoreBackupResponse(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    restored_rows: int
    ignored_receipt_files: int
