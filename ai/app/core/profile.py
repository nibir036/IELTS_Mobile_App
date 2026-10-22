"""The student profile.

Field names match the existing NextedProfile so the Node API can send its
rows straight across with no mapping layer.

Two rules that are easy to lose and expensive to lose:

1. A blank field means "the student has not told us", never "no" and never
   zero. Eligibility treats the two completely differently.
2. An academic result keeps the scale it was given on. Nothing here converts
   a CGPA into a percentage or a foreign grade.
"""
from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.core.numbers import num

# The ten fields the Node side keeps in PROFILE_FIELDS.
PROFILE_FIELDS = (
    "name",
    "phone",
    "nationality",
    "homeDistrict",
    "highestLevel",
    "result",
    "ieltsBand",
    "preferredCountry",
    "subject",
    "studyLevel",
    "intake",
)


class StudentProfile(BaseModel):
    """Everything we know about one student. Blank means unknown."""

    model_config = ConfigDict(populate_by_name=True, extra="ignore")

    name: str = ""
    phone: str = ""
    nationality: str = ""
    home_district: str = Field(default="", alias="homeDistrict")
    highest_level: str = Field(default="", alias="highestLevel")
    # Free text on purpose: students write "3.2", "3.2/4", "CGPA 3.20".
    result: str = ""
    ielts_band: str = Field(default="", alias="ieltsBand")
    preferred_country: str = Field(default="", alias="preferredCountry")
    subject: str = ""
    # The level they want to ENROL in (Bachelors, Masters, PhD ...). Not the
    # same as highest_level, which is what they have already finished.
    study_level: str = Field(default="", alias="studyLevel")
    intake: str = ""

    # ------------------------------------------------------------------
    @property
    def band(self) -> float | None:
        return num(self.ielts_band)

    @property
    def gpa(self) -> float | None:
        return num(self.result)

    def has(self, field: str) -> bool:
        """True when the student actually told us this one."""
        return bool(str(getattr(self, field, "") or "").strip())

    def blank_fields(self) -> list[str]:
        return [
            f
            for f in (
                "nationality",
                "home_district",
                "highest_level",
                "result",
                "ielts_band",
                "preferred_country",
                "subject",
                "study_level",
                "intake",
            )
            if not self.has(f)
        ]

    def is_empty(self) -> bool:
        """Nothing useful to personalise with.

        An empty profile is never personalised against - showing somebody a
        tailored list built from nothing is worse than showing them a plain
        one.
        """
        return not any(
            self.has(f)
            for f in ("nationality", "highest_level", "result", "ielts_band",
                      "preferred_country", "subject", "study_level")
        )

    def summary_lines(self) -> list[str]:
        """Short facts for a prompt. Only what we actually know."""
        out: list[str] = []
        if self.preferred_country:
            out.append(f"- Preferred country: {self.preferred_country}")
        if self.highest_level:
            out.append(f"- Highest level completed: {self.highest_level}")
        if self.study_level:
            out.append(f"- Wants to enrol in: {self.study_level}")
        if self.subject:
            out.append(f"- Subject they want to study: {self.subject}")
        if self.result:
            # Kept exactly as written, with its scale intact.
            out.append(f"- Academic result (as given): {self.result}")
        if self.ielts_band:
            out.append(f"- IELTS: {self.ielts_band}")
        else:
            out.append("- IELTS: not provided")
        if self.nationality:
            out.append(f"- Nationality: {self.nationality}")
        if self.home_district:
            out.append(f"- Home district: {self.home_district}")
        if self.intake:
            out.append(f"- Intended intake: {self.intake}")
        return out
