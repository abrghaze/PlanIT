from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class DeleteProfileRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    password: str = Field(strict=True, min_length=1, max_length=128)
    confirmation: Literal["DELETE MY PLANIT DATA"]
