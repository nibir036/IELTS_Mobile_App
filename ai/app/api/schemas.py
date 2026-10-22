"""Request shapes.

Note what the response models do NOT contain: no living-cost figure, no
internal verification date, no graph state, no prompt. A field that does
not exist cannot leak.
"""
from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.core.profile import StudentProfile


class HistoryTurn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    role: str = "student"
    content: str = ""


class CounsellorRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")
    # The Node API sends the student's profile across; this service never
    # queries the student tables itself.
    studentId: str = Field(min_length=1, max_length=128)
    profile: StudentProfile = Field(default_factory=StudentProfile)
    message: str = Field(min_length=1, max_length=4000)
    history: list[HistoryTurn] = Field(default_factory=list)


class FinderRequest(BaseModel):
    model_config = ConfigDict(extra="ignore")
    studentId: str = Field(min_length=1, max_length=128)
    profile: StudentProfile = Field(default_factory=StudentProfile)
    query: str = Field(default="", max_length=200)
