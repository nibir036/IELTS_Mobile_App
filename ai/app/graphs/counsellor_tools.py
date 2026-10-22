"""The counsellor's tools (LangGraph agent -> tools -> agent loop).

The model decides WHEN to call a tool; code decides what the tool does.
Every value a student gives in chat is validated here before it is written,
so the model cannot put "very good" into an IELTS band or invent a field.

  get_student_profile     what we know and what is still missing
  save_profile_details    write what the student just told us (validated);
                          the API server saves it to their profile
  get_office_contact      nextED's address, phone and Google Maps link
                          (also shows the office card in the app)
  find_courses            courses already in our catalogue for a subject
  find_scholarships       scholarships we hold, with an eligibility verdict
  best_opportunities      the student's own priority first, then the best
                          alternatives (other countries, awards they qualify for)
  show_buttons            buttons under the reply that open Course matching,
                          the Scholarship finder, the profile, call or directions

Tools return JSON text for the model. Anything the app must see (profile
changes, the office card) is collected in the state, never left to the
model to repeat.
"""
from __future__ import annotations

import json
import logging
import re

from app.core.profile import StudentProfile

log = logging.getLogger(__name__)

# Node's profile field -> StudentProfile attribute.
FIELD_MAP = {
    "fullName": "name",
    "phone": "phone",
    "nationality": "nationality",
    "homeDistrict": "home_district",
    "highestLevel": "highest_level",
    "result": "result",
    "ieltsBand": "ielts_band",
    "studyLevel": "study_level",
    "subject": "subject",
    "preferredCountry": "preferred_country",
    "preferredIntake": "intake",
}

LABELS = {
    "fullName": "Full name",
    "email": "Email",
    "phone": "Phone",
    "nationality": "Nationality",
    "homeDistrict": "Home district",
    "highestLevel": "Highest education",
    "result": "Result / GPA",
    "ieltsBand": "IELTS band",
    "studyLevel": "Level you want to study",
    "subject": "Subject you want to study",
    "preferredCountry": "Preferred country",
    "preferredIntake": "Preferred intake",
}

# What Course matching and the Scholarship finder need (same list as the app
# and the API server).
REQUIRED = ("fullName", "nationality", "highestLevel", "result", "ieltsBand",
            "studyLevel", "subject", "preferredCountry")


def value_of(profile: StudentProfile, field: str, extra: dict | None = None) -> str:
    if extra and field in extra:
        return str(extra[field])
    attr = FIELD_MAP.get(field)
    return str(getattr(profile, attr, "") or "").strip() if attr else ""


def missing_fields(profile: StudentProfile, updates: dict | None = None) -> list[str]:
    return [f for f in REQUIRED if not value_of(profile, f, updates)]


# ------------------------------------------------------------------ schemas
def _schema(name: str, description: str, properties: dict | None = None, required=None) -> dict:
    return {
        "type": "function",
        "function": {
            "name": name,
            "description": description,
            "parameters": {
                "type": "object",
                "properties": properties or {},
                **({"required": list(required)} if required else {}),
            },
        },
    }


_STR = {"type": "string"}

TOOLS = [
    _schema(
        "get_student_profile",
        "Read the student's saved profile and which details are still missing. "
        "Call this before asking the student for personal details, so you never "
        "ask for something we already have.",
    ),
    _schema(
        "save_profile_details",
        "Save details the student has clearly told you in this chat to their nextED "
        "profile. Only include fields they actually stated - never guess or infer. "
        "They can edit the profile later in the app.",
        {
            "fullName": {**_STR, "description": "Full name as the student gave it"},
            "email": _STR,
            "phone": {**_STR, "description": "Bangladeshi mobile number"},
            "nationality": {**_STR, "description": "e.g. Bangladeshi"},
            "homeDistrict": {**_STR, "description": "Home district in Bangladesh, e.g. Sylhet"},
            "highestLevel": {**_STR, "description": "Highest education FINISHED: SSC, HSC, A Level, Diploma, Bachelor, Masters, PhD"},
            "result": {**_STR, "description": "GPA/CGPA/result exactly as given, with its scale if stated, e.g. '3.45/4' or 'GPA 5.00'"},
            "ieltsBand": {**_STR, "description": "Overall IELTS band 0-9 (e.g. '6.5'), or 'Not yet' if they have not taken it"},
            "studyLevel": {**_STR, "description": "Level they want to ENROL in: Foundation, Diploma, Bachelors, Masters, MBA or PhD"},
            "subject": {**_STR, "description": "Subject they want to study, e.g. 'Computer Science'"},
            "preferredCountry": {**_STR, "description": "Country or countries they want, e.g. 'UK' or 'UK, Canada'"},
            "preferredIntake": {**_STR, "description": "e.g. 'September 2027'"},
        },
    ),
    _schema(
        "get_office_contact",
        "nextED's office address, phone number and Google Maps location. Use it "
        "whenever the student wants to call, visit, book a consultation, talk to a "
        "human, or asks where nextED is. The app shows a call/directions card.",
    ),
    _schema(
        "find_courses",
        "Look up courses already in nextED's catalogue. Leave a field empty to use "
        "the student's profile. Fast; it does not search the web.",
        {"subject": _STR, "level": _STR, "country": _STR},
    ),
    _schema(
        "find_scholarships",
        "Look up scholarships nextED holds, each with an eligibility verdict computed "
        "from the student's profile. Fast; it does not search the web.",
        {"country": _STR, "level": _STR},
    ),
]

# Buttons the app knows how to draw (type -> label). The app owns what they do.
BUTTONS = {
    "course_finder": "Find courses for me",
    "scholarship_finder": "Find scholarships for me",
    "complete_profile": "Complete my profile",
    "call_office": "Call nextED",
    "office_location": "Get directions",
}

TOOLS += [
    _schema(
        "best_opportunities",
        "The student's best options from what nextED holds: matches for their own "
        "subject and country FIRST, then strong alternatives - the same subject in "
        "other countries, and scholarships they are eligible for anywhere. Use it "
        "when they ask what fits them, seem unsure, or their first choice is thin.",
    ),
    _schema(
        "show_buttons",
        "Show tappable buttons under your reply. course_finder opens Course matching "
        "(live search of universities), scholarship_finder opens the Scholarship "
        "finder, complete_profile opens their profile, call_office dials nextED, "
        "office_location opens Google Maps directions. Use whenever you mention one "
        "of these, so the student can act in one tap.",
        {"buttons": {"type": "array", "items": {"type": "string", "enum": list(BUTTONS)}}},
        required=["buttons"],
    ),
]

TOOL_NAMES = {t["function"]["name"] for t in TOOLS}


def add_actions(state: dict, *types: str) -> list[dict]:
    """The state's buttons plus these, each once, in order."""
    actions = list(state.get("actions") or [])
    have = {a["type"] for a in actions}
    for t in types:
        if t in BUTTONS and t not in have:
            actions.append({"type": t, "label": BUTTONS[t]})
            have.add(t)
    return actions


# --------------------------------------------------------------- validation
_LEVELS = (
    (("phd", "doctor", "doctorate", "dphil"), "PhD"),
    (("mba",), "MBA"),
    (("master", "msc", "m.sc", "ma ", "mphil", "meng", "postgrad"), "Masters"),
    (("bachelor", "bsc", "b.sc", "ba ", "beng", "bba", "undergrad", "honours", "hons"), "Bachelors"),
    (("diploma", "hnd"), "Diploma"),
    (("foundation",), "Foundation"),
)


def _study_level(text: str) -> str:
    low = f" {text.lower().strip()} "
    for keys, name in _LEVELS:
        if any(k in low for k in keys):
            return name
    return ""


def _band(text: str) -> str:
    low = text.lower().strip()
    if any(w in low for w in ("not yet", "not taken", "none", "no ielts", "haven't", "have not", "planning")):
        return "Not yet"
    match = re.search(r"\d+(\.\d+)?", low)
    if not match:
        return ""
    value = float(match.group(0))
    if not 0 <= value <= 9:
        return ""
    value = round(value * 2) / 2  # IELTS bands are in halves
    return f"{value:g}"


def clean_details(raw: dict) -> tuple[dict, dict]:
    """(accepted, rejected-with-reason). Only known fields, sane values."""
    accepted: dict[str, str] = {}
    rejected: dict[str, str] = {}
    for key, value in (raw or {}).items():
        if key not in LABELS:
            continue
        text = " ".join(str(value or "").split())[:120]
        if not text:
            continue
        if key == "ieltsBand":
            band = _band(text)
            if not band:
                rejected[key] = "An IELTS band is a number from 0 to 9 (like 6.5), or 'Not yet'."
                continue
            text = band
        elif key == "studyLevel":
            level = _study_level(text)
            if not level:
                rejected[key] = "Use one of: Foundation, Diploma, Bachelors, Masters, MBA, PhD."
                continue
            text = level
        elif key == "email" and not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", text):
            rejected[key] = "That does not look like an email address."
            continue
        elif key == "phone":
            digits = re.sub(r"[^\d+]", "", text)
            if len(re.sub(r"\D", "", digits)) < 10:
                rejected[key] = "A phone number needs at least 10 digits."
                continue
            text = digits
        accepted[key] = text
    return accepted, rejected


def apply_to_profile(profile: StudentProfile, accepted: dict) -> StudentProfile:
    data = profile.model_dump()
    for key, value in accepted.items():
        attr = FIELD_MAP.get(key)
        if attr:
            data[attr] = value
    return StudentProfile.model_validate(data)


# ------------------------------------------------------------------ running
def _fact(value) -> str:
    v = getattr(value, "value", value)
    return "" if v in (None, "") else str(v)


async def run_tool(name: str, args: dict, state: dict) -> tuple[str, dict]:
    """(JSON text for the model, state updates)."""
    profile: StudentProfile = state["profile"]
    updates = dict(state.get("profile_updates") or {})

    if name == "get_student_profile":
        known = {LABELS[f]: value_of(profile, f, updates) for f in LABELS if value_of(profile, f, updates)}
        missing = [LABELS[f] for f in missing_fields(profile, updates)]
        return json.dumps({
            "known": known,
            "missing_for_course_and_scholarship_matching": missing,
            "complete": not missing,
        }, ensure_ascii=False), {}

    if name == "save_profile_details":
        accepted, rejected = clean_details(args)
        if not accepted:
            return json.dumps({"saved": {}, "rejected": rejected or {"_": "Nothing to save."}}), {}
        updates.update(accepted)
        new_profile = apply_to_profile(profile, accepted)
        still = [LABELS[f] for f in missing_fields(new_profile, updates)]
        log.info("counsellor saved profile fields: %s", ", ".join(accepted))
        return json.dumps({
            "saved": {LABELS[k]: v for k, v in accepted.items()},
            "rejected": rejected,
            "still_missing": still,
            "note": "Tell the student in one short line what you saved; they can edit it in Profile.",
        }, ensure_ascii=False), {"profile": new_profile, "profile_updates": updates}

    if name == "get_office_contact":
        s = state.get("settings")
        office = {
            "name": getattr(s, "office_name", "nextED"),
            "address": getattr(s, "office_address", ""),
            "phone": getattr(s, "office_phone_display", ""),
            "google_maps": getattr(s, "office_maps_url", ""),
        }
        office["note"] = ("Give the phone number and the Google Maps link in your reply now - "
                          "do not ask whether they want them. Call and Directions buttons are shown.")
        return json.dumps(office, ensure_ascii=False), {
            "show_contact": True,
            "actions": add_actions(state, "call_office", "office_location"),
        }

    if name == "show_buttons":
        wanted = [b for b in (args.get("buttons") or []) if b in BUTTONS]
        if not wanted:
            return json.dumps({"shown": [], "error": f"Use: {', '.join(BUTTONS)}"}), {}
        return json.dumps({"shown": wanted}), {"actions": add_actions(state, *wanted)}

    if name == "best_opportunities":
        return await _best_opportunities(state), {}

    if name == "find_courses":
        return await _find_courses(args, state), {}

    if name == "find_scholarships":
        return await _find_scholarships(args, state), {}

    return json.dumps({"error": f"unknown tool {name}"}), {}


def _lookup_state(state: dict, args: dict, kind: str) -> dict:
    from app.core.eligibility import level_in_text, level_to_study

    profile: StudentProfile = state["profile"]
    level = args.get("level") or profile.study_level or level_to_study(profile.highest_level)
    return {
        **state,
        "kind": kind,
        "query": args.get("subject") or "",
        "constraints": {
            "subject": args.get("subject") or profile.subject,
            "level": level_in_text(level) or level,
            "country": args.get("country") or profile.preferred_country,
            "keywords": [],
        },
    }


_SAME = {"united kingdom": "uk", "england": "uk", "scotland": "uk", "wales": "uk",
         "united states": "usa", "us": "usa"}


def _norm(name: str) -> str:
    low = name.lower().strip()
    return _SAME.get(low, low)


def _country_ok(row, country: str) -> bool:
    from app.kb.retrieve import countries_of

    wanted = {_norm(c) for c in countries_of(country, True)}
    if not wanted:
        return True
    have = {_norm(c) for c in countries_of(row.country or "", True)} or {_norm(row.country or "")}
    return bool(wanted & have)


async def _find_courses(args: dict, state: dict) -> str:
    from app.kb.retrieve import keep_relevant

    look = _lookup_state(state, args, "course")
    rows = await keep_relevant(look, list(state["store"].courses.values()), "course")
    country = look["constraints"]["country"] or ""
    in_country = [r for r in rows if _country_ok(r, country)]
    rows = (in_country or rows)[:5]
    out = [{
        "title": r.title, "university": r.university, "country": r.country, "level": r.level,
        "tuition": _fact(r.tuition), "min_ielts": _fact(r.min_ielts), "deadline": _fact(r.deadline),
        "link": r.official_url,
    } for r in rows]
    return json.dumps({
        "courses": out,
        "note": ("Only what nextED already holds. For a full live search, suggest the "
                 "Course matching screen in the app.") if out else
                "Nothing stored for that yet. Suggest the Course matching screen, which reads universities' pages.",
        "other_countries_only": bool(rows) and not in_country and bool(country),
    }, ensure_ascii=False)


async def _find_scholarships(args: dict, state: dict) -> str:
    from app.core.eligibility import eligibility
    from app.kb.retrieve import keep_relevant

    look = _lookup_state(state, args, "scholarship")
    rows = await keep_relevant(look, list(state["store"].scholarships.values()), "scholarship")
    country = look["constraints"]["country"] or ""
    rows = [r for r in rows if _country_ok(r, country)] or rows
    out = []
    for r in rows[:5]:
        verdict = eligibility(state["profile"], r)
        out.append({
            "title": r.title, "provider": r.provider, "country": r.country, "level": r.level,
            "amount": _fact(r.amount), "deadline": _fact(r.deadline),
            "verdict": verdict.verdict.value, "why": verdict.facts[:3], "link": r.official_url,
        })
    return json.dumps({
        "scholarships": out,
        "note": "Verdicts are computed in code from the profile. For more, suggest the Scholarship finder screen.",
    }, ensure_ascii=False)


async def _best_opportunities(state: dict) -> str:
    """Their priority first, then what else is genuinely strong for them."""
    from app.core.eligibility import eligibility
    from app.kb.retrieve import countries_of, keep_relevant

    profile: StudentProfile = state["profile"]
    look = _lookup_state(state, {}, "course")
    country = look["constraints"]["country"] or ""
    relevant = await keep_relevant(look, list(state["store"].courses.values()), "course")
    mine = [r for r in relevant if _country_ok(r, country)]
    elsewhere = [r for r in relevant if not _country_ok(r, country)]

    def course(r) -> dict:
        return {"title": r.title, "university": r.university, "country": r.country,
                "level": r.level, "tuition": _fact(r.tuition), "min_ielts": _fact(r.min_ielts)}

    # One per country for the alternatives, so it reads as a real choice.
    seen: set[str] = set()
    other = []
    for r in elsewhere:
        key = (r.country or "").lower()
        if key and key not in seen:
            seen.add(key)
            other.append(course(r))
        if len(other) >= 3:
            break

    awards = []
    for r in state["store"].scholarships.values():
        verdict = eligibility(profile, r)
        if verdict.verdict.value in ("Eligible", "Borderline"):
            awards.append((0 if verdict.verdict.value == "Eligible" else 1, r, verdict))
    awards.sort(key=lambda x: x[0])
    # "Chevening", "Chevening Scholarship", "Bangladesh (Chevening Scholarship)"
    # are one award to a student.
    unique, keys = [], []
    for item in awards:
        key = re.sub(r"[^a-z ]", " ", item[1].title.lower())
        key = " ".join(w for w in key.split() if w not in {"bangladesh", "scholarship", "scholarships", "award", "the"})
        if any(key and (key in k or k in key) for k in keys):
            continue
        keys.append(key)
        unique.append(item)
    awards = unique

    band = profile.band
    strengths, boosts = [], []
    if band is not None and band >= 6.5:
        strengths.append(f"IELTS {band:g} meets most postgraduate requirements")
    elif band is not None:
        boosts.append(f"Raising IELTS from {band:g} to 6.5+ opens many more universities and awards")
    elif not profile.ielts_band:
        boosts.append("An IELTS score (most ask 6.0-6.5) is the single biggest unlock")
    if profile.gpa is not None:
        strengths.append(f"result {profile.result} on record")

    return json.dumps({
        "their_priority": {
            "wanted": {"subject": look["constraints"]["subject"], "level": look["constraints"]["level"],
                       "countries": countries_of(country, True) or [country]},
            "matches": [course(r) for r in mine[:4]],
        },
        "alternatives_same_subject_other_countries": other,
        "scholarships_they_qualify_for": [
            {"title": r.title, "provider": r.provider, "country": r.country,
             "amount": _fact(r.amount), "verdict": v.verdict.value, "why": v.facts[:2]}
            for _, r, v in awards[:4]
        ],
        "profile_strengths": strengths,
        "what_would_open_more_doors": boosts,
        "how_to_present": ("Lead with their priority. Then 'Also worth a look:' with at most 2-3 "
                           "alternatives and one line on why each is strong (cost, scholarship, "
                           "entry, work rights - only from these facts). Offer the course_finder "
                           "and scholarship_finder buttons, and a nextED counsellor to compare options."),
    }, ensure_ascii=False)
