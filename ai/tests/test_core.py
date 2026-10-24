"""Tests for the decision layer.

No model, no network, no database. Every outcome here is deterministic,
which is exactly why this is the part to finish first.

Run with `pytest -q`, or with `python tests/run.py` if pytest is not
installed.
"""
from __future__ import annotations

import json
import pathlib
from datetime import datetime, timedelta, timezone

from app.core.budget import ResearchBudget
from app.core.catalogue import Scholarship, make_fact
from app.core.eligibility import Verdict, eligibility
from app.core.evidence import ExtractedField, is_backed, keep_backed
from app.core.freshness import (
    Fact,
    FieldClass,
    Freshness,
    can_state_plainly,
    diff_facts,
    freshness,
    must_recheck,
    stalest_first,
    touch_unchanged,
)
from app.core.gaps import biggest_gap
from app.core.numbers import num
from app.core.profile import StudentProfile
from app.core.restrictions import (
    RestrictionRule,
    Status,
    StudentScope,
    check_restrictions,
    flag_closed,
    same_university,
)
from app.core.search import course_tiers, first_non_empty, search_words

ROOT = pathlib.Path(__file__).resolve().parents[1]
NOW = datetime(2026, 10, 20, tzinfo=timezone.utc)


def _student(name: str) -> StudentProfile:
    raw = json.loads((ROOT / "examples" / "students" / f"{name}.json").read_text())
    return StudentProfile.model_validate(raw)


def _rules() -> list[RestrictionRule]:
    raw = json.loads((ROOT / "examples" / "restrictions.sample.json").read_text())
    return [RestrictionRule.from_row(r) for r in raw]


# ======================================================== reading numbers
def test_num_handles_what_students_actually_type():
    assert num("7.0 (overall)") == 7.0
    assert num("6.5") == 6.5
    assert num("3.2 / 4.0") == 3.2          # the old TS version failed here
    assert num("CGPA 3.70 out of 4") == 3.70
    assert num("band 7") == 7.0
    assert num("18,000") == 18000.0
    assert num("") is None
    assert num(None) is None
    assert num("not taken") is None


# ============================================================== profile
def test_blank_is_unknown_not_zero():
    thin = _student("thin")
    assert thin.band is None
    assert thin.gpa is None
    assert not thin.has("ielts_band")
    assert "ielts_band" in thin.blank_fields()


def test_empty_profile_is_recognised():
    assert _student("empty").is_empty()
    assert not _student("strong").is_empty()
    # a country alone is not enough to personalise on
    assert _student("thin").is_empty() is False  # has highestLevel + country


def test_result_keeps_its_scale():
    strong = _student("strong")
    lines = " ".join(strong.summary_lines())
    assert "3.70 / 4.00" in lines  # never converted to a percentage


def test_publication_reaches_the_prompt():
    from app.core.profile import StudentProfile

    yes = StudentProfile.model_validate({"hasPublication": "Yes", "subject": "Physics"})
    assert "- Has a research publication: Yes" in yes.summary_lines()
    # Not answered: nothing is said about it either way.
    blank = StudentProfile.model_validate({"subject": "Physics"})
    assert not any("publication" in line for line in blank.summary_lines())


# ========================================================= restrictions
def test_exact_match_only():
    assert same_university("Oxford Brookes University", "oxford brookes")
    assert same_university("The University of Example", "Example University")
    # the pair that must never be confused
    assert not same_university(
        "Oxford Brookes University", "Oxford International Education Group"
    )


def test_a_full_rule_closes():
    check = check_restrictions(
        _rules(), "Example Metropolitan University", StudentScope.of(_student("strong"))
    )
    assert check.status is Status.closed
    assert check.needs_counsellor
    # wording: partner information, never a claim about the university
    assert "reject" not in check.message.lower()
    assert "NextED" in check.message


def test_a_university_with_no_rule_is_open():
    check = check_restrictions(
        _rules(), "Some Other University", StudentScope.of(_student("strong"))
    )
    assert check.status is Status.open


def test_retired_rules_are_ignored():
    check = check_restrictions(
        _rules(), "Example Coastal University", StudentScope.of(_student("strong"))
    )
    assert check.status is Status.open


def test_blank_home_district_never_closes_a_door():
    """The rule that must not be softened."""
    thin = _student("thin")  # homeDistrict is ""
    scope = StudentScope(home_district="", level="undergraduate", subject="", intake="")
    check = check_restrictions(_rules(), "Example Riverside University", scope)
    assert check.status is Status.check      # never Status.closed
    assert check.needs_home_district is True


def test_a_matching_region_does_close():
    scope = StudentScope(home_district="Sylhet", level="undergraduate")
    check = check_restrictions(_rules(), "Example Riverside University", scope)
    assert check.status is Status.closed


def test_an_excepted_region_is_carved_out():
    scope = StudentScope(home_district="Dhaka", level="undergraduate")
    check = check_restrictions(_rules(), "Example Riverside University", scope)
    assert check.status is Status.open


def test_a_different_level_does_not_match():
    scope = StudentScope(home_district="Sylhet", level="masters")
    check = check_restrictions(_rules(), "Example Riverside University", scope)
    assert check.status is Status.open


def test_unknown_subject_downgrades_to_check():
    scope = StudentScope(home_district="Dhaka", level="masters", subject="")
    check = check_restrictions(_rules(), "Example Northern University", scope)
    assert check.status is Status.check


def test_flag_closed_catches_what_the_model_forgot():
    reply = (
        "You could look at Example Metropolitan University, which has a good "
        "computer science department."
    )
    flagged = flag_closed(reply, _rules(), StudentScope.of(_student("strong")))
    assert len(flagged) == 1
    assert flagged[0]["university"] == "Example Metropolitan University"


def test_flag_closed_stays_quiet_when_nothing_is_wrong():
    reply = "Some Other University might suit you."
    assert flag_closed(reply, _rules(), StudentScope.of(_student("strong"))) == []


# ========================================================== eligibility
def _sch(**kwargs) -> Scholarship:
    base = dict(id="s1", title="Test Award", provider="Test", country="United Kingdom")
    base.update(kwargs)
    return Scholarship(**base)


def test_clear_pass():
    result = eligibility(_student("strong"), _sch(min_ielts=6.5, min_gpa=3.0))
    assert result.verdict is Verdict.eligible


def test_half_a_band_short_is_borderline():
    student = _student("borderline")  # 6.5
    result = eligibility(student, _sch(min_ielts=7.0))
    assert result.verdict is Verdict.borderline
    assert result.near_miss and not result.hard_fail


def test_more_than_half_a_band_short_fails():
    student = _student("borderline")  # 6.5
    result = eligibility(student, _sch(min_ielts=7.5))
    assert result.verdict is Verdict.not_eligible
    assert result.hard_fail


def test_gpa_near_miss_boundary():
    student = _student("borderline")  # 3.2
    assert eligibility(student, _sch(min_gpa=3.5)).verdict is Verdict.borderline
    assert eligibility(student, _sch(min_gpa=3.6)).verdict is Verdict.not_eligible


def test_unknown_is_not_the_same_as_not_eligible():
    """The distinction that makes 'unlock more' honest."""
    thin = _student("thin")  # no band at all
    result = eligibility(thin, _sch(min_ielts=7.0))
    assert result.verdict is Verdict.borderline   # NOT not_eligible
    assert result.unknown
    assert "ieltsBand" in result.missing_fields
    assert not result.hard_fail


def test_nationality_not_listed_is_a_hard_fail():
    result = eligibility(
        _student("strong"), _sch(nationalities=("India", "Pakistan"))
    )
    assert result.verdict is Verdict.not_eligible


def test_nationality_listed_passes():
    result = eligibility(
        _student("strong"), _sch(nationalities=("Bangladesh", "India"))
    )
    assert result.verdict is Verdict.eligible


def test_missing_nationality_is_borderline():
    result = eligibility(_student("thin"), _sch(nationalities=("Bangladesh",)))
    assert result.verdict is Verdict.borderline


def test_requirements_may_arrive_as_facts_with_sources():
    """A requirement read off a page works exactly like a plain number."""
    scholarship = _sch(
        min_ielts=make_fact(7.0, "min_ielts", "https://example.ac.uk/x", "IELTS 7.0 required")
    )
    assert eligibility(_student("strong"), scholarship).verdict is Verdict.eligible
    assert eligibility(_student("borderline"), scholarship).verdict is Verdict.borderline


# ================================================================= gaps
def test_gap_states_the_real_distance_and_counts_honestly():
    student = _student("borderline")  # 6.5
    items = [
        _sch(id="a", min_ielts=7.0),
        _sch(id="b", min_ielts=7.0),
        _sch(id="c", min_ielts=6.0),
        _sch(id="d", min_ielts=8.0),
    ]
    gap = biggest_gap(student, items)
    assert gap is not None
    assert gap.field == "ieltsBand"
    assert gap.needed == 7.0
    assert gap.unlocks == 2            # a and b, not d
    assert "6.5" in gap.message and "7" in gap.message


def test_no_gap_is_offered_for_an_empty_profile():
    assert biggest_gap(_student("empty"), [_sch(min_ielts=7.0)]) is None


def test_no_gap_when_nothing_would_unlock():
    student = _student("strong")  # 7.5
    assert biggest_gap(student, [_sch(min_ielts=6.0)]) is None


def test_a_missing_field_is_offered_as_a_gap():
    gap = biggest_gap(_student("thin"), [_sch(min_ielts=6.0), _sch(id="b", min_ielts=6.5)])
    assert gap is not None
    assert gap.field == "ieltsBand"
    assert "Add" in gap.message


# =========================================================== freshness
def _fact(days_old: float, field_class: FieldClass) -> Fact:
    return Fact(
        value="15 January 2027",
        field_class=field_class,
        source_url="https://example.ac.uk/course",
        evidence="Applications close on 15 January 2027.",
        checked_at=NOW - timedelta(days=days_old),
    )


def test_a_deadline_goes_stale_in_a_week():
    assert freshness(_fact(3, FieldClass.deadline), NOW) is Freshness.fresh
    assert freshness(_fact(10, FieldClass.deadline), NOW) is Freshness.needs_recheck


def test_a_country_does_not_go_stale_in_a_week():
    assert freshness(_fact(10, FieldClass.identity), NOW) is Freshness.fresh


def test_an_old_deadline_may_not_be_stated_plainly():
    old = _fact(30, FieldClass.deadline)
    assert must_recheck(old, NOW)
    assert not can_state_plainly(old, NOW)


def test_a_value_with_no_source_is_never_trusted():
    bare = Fact(value="15 January 2027", field_class=FieldClass.deadline)
    assert freshness(bare, NOW) is Freshness.unconfirmed
    assert not can_state_plainly(bare, NOW)


def test_rechecking_and_finding_no_change_restarts_the_clock():
    old = _fact(30, FieldClass.deadline)
    assert must_recheck(old, NOW)
    touch_unchanged(old, NOW)
    assert not must_recheck(old, NOW)


def test_the_most_overdue_field_is_fetched_first():
    facts = {
        "tuition": _fact(100, FieldClass.money),      # 100/90  = 1.11x over
        "deadline": _fact(30, FieldClass.deadline),   # 30/7    = 4.3x over
        "country": _fact(10, FieldClass.identity),    # not over
    }
    order = stalest_first(facts, NOW)
    assert order[0] == "deadline"
    assert "country" not in order


def test_a_moved_deadline_becomes_something_we_can_tell_the_student():
    old = {"deadline": _fact(30, FieldClass.deadline)}
    new = {
        "deadline": Fact(
            value="29 January 2027",
            field_class=FieldClass.deadline,
            source_url="https://example.ac.uk/course",
            evidence="Applications close on 29 January 2027.",
            checked_at=NOW,
        )
    }
    changes = diff_facts(old, new)
    assert len(changes) == 1
    message = changes[0].message()
    assert "15 January 2027" in message and "29 January 2027" in message
    assert "moved" in message


# ============================================================ evidence
def test_a_number_must_appear_in_its_evidence():
    ok, _ = is_backed(
        ExtractedField(
            "min_ielts", 7.0,
            evidence="Applicants need an overall IELTS score of 7.0.",
            source_url="https://example.ac.uk/entry",
        )
    )
    assert ok


def test_an_invented_number_is_dropped():
    ok, why = is_backed(
        ExtractedField(
            "min_ielts", 7.0,
            evidence="Applicants need a good level of English.",
            source_url="https://example.ac.uk/entry",
        )
    )
    assert not ok
    assert "number" in why


def test_a_fact_with_no_evidence_is_dropped():
    ok, why = is_backed(
        ExtractedField("tuition", 18000, evidence="", source_url="https://x.ac.uk")
    )
    assert not ok


def test_a_fact_with_no_source_is_dropped():
    ok, why = is_backed(
        ExtractedField("tuition", 18000, evidence="Fees are £18,000.", source_url="")
    )
    assert not ok


def test_a_tuition_figure_written_with_a_comma_is_accepted():
    ok, _ = is_backed(
        ExtractedField(
            "tuition", 18000,
            evidence="Tuition for 2027 entry is £18,000 per year.",
            source_url="https://example.ac.uk/fees",
        )
    )
    assert ok


def test_a_date_must_appear_in_its_evidence():
    good = ExtractedField(
        "deadline", "2027-01-15",
        evidence="The deadline for applications is 15 January 2027.",
        source_url="https://example.ac.uk/apply",
    )
    bad = ExtractedField(
        "deadline", "2027-01-15",
        evidence="Applications are now open for 2027 entry.",
        source_url="https://example.ac.uk/apply",
    )
    assert is_backed(good)[0]
    assert not is_backed(bad)[0]


def test_keep_backed_splits_the_good_from_the_invented():
    fields = [
        ExtractedField("min_ielts", 6.5, "An IELTS score of 6.5 is required.", "https://x.ac.uk"),
        ExtractedField("tuition", 20000, "The course is taught over one year.", "https://x.ac.uk"),
    ]
    kept, dropped = keep_backed(fields)
    assert [f.name for f in kept] == ["min_ielts"]
    assert [d.field for d in dropped] == ["tuition"]


# =============================================================== search
def test_short_words_still_search():
    """The bug that made typing 'ict' return nothing."""
    assert search_words("ict courses in the uk") == ["ict", "uk"]


def test_stop_words_are_dropped():
    assert search_words("I want to find a good university program") == []


def test_search_falls_back_rather_than_showing_nothing():
    class Row:
        def __init__(self, title, country):
            self.title = title
            self.country = country
            self.subject = ""
            self.university = ""
            self.level = ""

    rows = [Row("Marine Biology MSc", "United Kingdom")]
    words = search_words("quantum computing")
    result = first_non_empty(rows, course_tiers(words, "United Kingdom", "quantum computing"))
    assert result.rows                       # never an empty screen
    assert "quantum computing" in result.note
    assert result.tier == "country"


def test_an_empty_store_says_so_rather_than_pretending():
    words = search_words("anything")
    result = first_non_empty([], course_tiers(words, "United Kingdom", "anything"))
    assert result.empty
    assert result.exhausted                  # the caller should go and look


# =============================================================== budget
def test_the_research_loop_stops_when_the_budget_is_gone():
    budget = ResearchBudget(max_searches=2, max_fetches=3)
    assert budget.can_search()
    budget.spend_search()
    budget.spend_search()
    assert not budget.can_search()
    assert "search limit" in budget.stopped_because

    # Spending the whole budget on work that finished is not running out.
    # The apology is only honest if something was actually left unread.
    assert budget.student_note() == ""
    budget.note_unread(3)
    assert budget.student_note()


def test_a_finished_search_never_apologises():
    """The note used to fire whenever the budget was fully spent.

    That turned every complete answer into "I ran out of time", including
    runs that read everything they found - which teaches students to
    distrust the one message that should mean something.
    """
    budget = ResearchBudget(max_searches=1, max_fetches=2)
    budget.spend_search()
    budget.spend_fetch()
    budget.spend_fetch()
    assert not budget.can_fetch()            # fully spent
    assert budget.student_note() == ""       # but nothing was missed


def test_fetches_are_counted_separately():
    budget = ResearchBudget(max_fetches=1)
    budget.spend_fetch()
    assert not budget.can_fetch()


def test_flag_closed_does_not_fire_on_a_longer_different_name():
    """The near-name trap: a closed 'X University' must not fire on
    'X University of Technology', which is a different institution."""
    rules = [
        RestrictionRule.from_row(
            {"university": "Example University", "kind": "full", "note": "closed"}
        )
    ]
    reply = "I'd suggest looking at the Example University of Technology instead."
    assert flag_closed(reply, rules, StudentScope()) == []


def test_flag_closed_still_fires_on_the_real_mention():
    rules = [
        RestrictionRule.from_row(
            {"university": "Example University", "kind": "full", "note": "closed"}
        )
    ]
    reply = "Example University is worth a look, and so is Other University."
    flagged = flag_closed(reply, rules, StudentScope())
    assert [f["university"] for f in flagged] == ["Example University"]


def test_a_short_rule_name_cannot_fire_on_a_longer_university():
    """A rule about 'Oxford' must never flag a reply about Oxford Brookes."""
    rules = [
        RestrictionRule.from_row({"university": "Oxford Brookes University",
                                  "kind": "full", "note": "closed"}),
    ]
    reply = "Oxford International Education Group runs pathway programmes."
    assert flag_closed(reply, rules, StudentScope()) == []


def test_a_bachelors_graduate_fits_a_masters_award():
    """The most common case in the whole product.

    'highestLevel' is what the student finished; a scholarship's 'level' is
    what they would study. Comparing the two strings directly marked every
    Bachelors graduate Borderline for a Masters award.
    """
    from app.core.eligibility import level_fits

    assert level_fits("Bachelors", "Masters")[0]
    assert level_fits("Bachelors", "Bachelors")[0]
    assert level_fits("Masters", "PhD")[0]
    assert level_fits("HSC", "Bachelors")[0]
    # two rungs up needs the step in between
    assert not level_fits("HSC", "Masters")[0]
    assert not level_fits("Bachelors", "PhD")[0]


def test_level_wording_variants_are_understood():
    from app.core.eligibility import level_fits

    assert level_fits("BSc Computer Science", "MSc")[0]
    assert level_fits("undergraduate", "postgraduate")[0]


def test_a_bachelors_student_is_eligible_for_a_masters_scholarship():
    student = _student("strong")           # Bachelors, band 7.5
    award = _sch(level="Masters", min_ielts=7.0)
    assert eligibility(student, award).verdict is Verdict.eligible


def test_the_level_searched_for_is_the_one_wanted_not_the_one_held():
    """A Bachelors graduate is looking for a Masters.

    The profile records what a student HAS finished. A course search needs
    what they want to STUDY. Reading the first as the second sent a
    Bachelors graduate a query for Bachelors courses.
    """
    from app.core.eligibility import level_to_study

    assert level_to_study("Bachelors") == "Masters"
    assert level_to_study("HSC") == "Bachelors"
    assert level_to_study("Masters") == "PhD"
    assert level_to_study("PhD") == "PhD"      # nothing above it
    assert level_to_study("") == ""            # unknown stays unknown


def test_the_students_own_word_sets_the_level():
    """"msc computer science" is a Masters request, whatever the profile says."""
    from app.core.eligibility import level_in_text

    assert level_in_text("msc computer science") == "Masters"
    assert level_in_text("MSc Artificial Intelligence") == "Masters"
    assert level_in_text("phd in robotics") == "PhD"
    assert level_in_text("ma business") == "Masters"
    assert level_in_text("bachelor of business") == "Bachelors"
    # no level named - the caller falls back to the profile
    assert level_in_text("computer science") == ""
    # must not fire inside an ordinary word
    assert level_in_text("management studies") == ""


# ============================================ what the model gets to read
def test_the_trim_keeps_what_the_page_is_not_only_what_it_says():
    """A course page's heading contains no requirement keywords.

    Scoring lines purely by keyword hits therefore discards the course
    name and the university, while one-word navigation links like "Fees"
    survive. A real 38,000-character Lincoln page reached the model with
    its own title missing, and the model correctly reported that it could
    not name the course.
    """
    from app.tools.extract import _trim_for_prompt
    from app.tools.fetch import Page

    nav = "\n".join(["Fees", "Apply", "Entry requirements", "Costs"] * 300)
    body = (
        "The entry requirement for this programme is a 2:1 honours degree, "
        "and applicants whose first language is not English need IELTS 6.5 "
        "overall with no less than 6.0 in each element."
    )
    page = Page(
        url="https://www.lincoln.ac.uk/course/cmpcmpms",
        status=200,
        text=("MSc Computer Science\nUniversity of Lincoln\n"
              "School of Computer Science\n" + nav + "\n" + body + "\n" + nav),
    )

    out = _trim_for_prompt(page)

    assert "MSc Computer Science" in out       # what the page is
    assert "University of Lincoln" in out      # who it belongs to
    assert "IELTS 6.5 overall" in out          # what it says
    assert len(out) <= 6_000


def test_a_short_page_is_passed_through_whole():
    from app.tools.extract import _trim_for_prompt
    from app.tools.fetch import Page

    page = Page(url="https://example.ac.uk/x", status=200, text="Short page.")
    assert _trim_for_prompt(page) == "Short page."


# =================================== shapes real models actually return
def test_facts_are_read_from_whatever_shape_the_model_used():
    """The schema asks for a list; smaller models answer in other shapes.

    Every one of these came back from a live run where the page was
    fetched, the model was paid for, and the facts were discarded in
    silence because the wrapper was not the one requested.
    """
    from app.tools.extract import _as_field_list

    want = [{"name": "min_ielts", "value": 6.5, "evidence": ""}]

    assert _as_field_list(
        {"fields": [{"name": "min_ielts", "value": 6.5}]}) == want
    assert _as_field_list(
        {"fields": [{"field": "min_ielts", "val": 6.5}]}) == want
    assert _as_field_list({"fields": {"min_ielts": 6.5}}) == want
    assert _as_field_list({"facts": [{"name": "min_ielts", "value": 6.5}]}) == want
    # the fields sitting at the top level beside the title
    assert _as_field_list(
        {"title": "MSc CS", "min_ielts": 6.5}) == want
    # a field we do not recognise is not invented into one
    assert _as_field_list({"fields": [{"name": "ranking", "value": 12}]}) == []


def test_a_guide_article_is_not_offered_as_a_course():
    """Shown as a course, an article sends a student somewhere to apply.

    All of these were returned by a real search and all of them have a
    university's name on them, so nothing but the title distinguishes
    them from a course page.
    """
    from app.tools.extract import looks_like_an_article

    assert looks_like_an_article("What is an MSc in Computer Science? 2026 Guide")
    assert looks_like_an_article("Is a masters degree in computer science worth it?")
    assert looks_like_an_article("WHAT ARE THE BENEFITS OF MSC COMPUTING")
    assert looks_like_an_article("Top 10 universities for computing")

    assert not looks_like_an_article("MSc Computer Science")
    assert not looks_like_an_article("MSc in Advanced Computer Science")
    assert not looks_like_an_article("Online MSc Computer Science")


def test_an_article_the_model_retitled_is_caught_by_its_address():
    """A model asked to read an article will summarise it as a course.

    This one came back titled "MSc in Computer Science" carrying a
    tuition figure the article had quoted as an example - a course that
    does not exist, with a price. The title gave nothing away; the URL
    it was published under did.
    """
    from app.tools.extract import looks_like_an_article

    assert looks_like_an_article(
        "MSc in Computer Science",
        "https://www.walbrook.ac.uk/subjects/computer-science/"
        "what-is-an-msc-in-computer-science/",
    )
    assert looks_like_an_article(
        "MSc Computer Science",
        "https://online.aston.ac.uk/blog/is-a-masters-degree-worth-it-in-2026",
    )

    # and the real course pages from the same run are untouched
    for title, url in (
        ("MSc Computer Science", "https://www.uos.ac.uk/study/msc-computer-science/"),
        ("Online MSc Computer Science",
         "https://online.abertay.ac.uk/programmes/msc-computer-science/"),
        ("Online MSc Computer Science: Career Advancement",
         "https://www.walbrook.ac.uk/degrees/postgraduate/msc-computer-science-online/"),
        ("Computer Science MSc", "https://www.lincoln.ac.uk/course/cmpcmpms/"),
    ):
        assert not looks_like_an_article(title, url), url


def test_the_site_name_is_stripped_but_the_level_is_kept():
    """A page title is the browser tab, not the course."""
    from app.tools.extract import clean_title

    assert clean_title("MSc Computer Science | University of Suffolk",
                       "University of Suffolk") == "MSc Computer Science"
    assert clean_title("MSc Data Science - Imperial College London",
                       "Imperial College London") == "MSc Data Science"
    # taking the head would drop the MSc, which is the part that matters
    assert clean_title("Computer Science | MSc | University of Lincoln",
                       "University of Lincoln") == "Computer Science MSc"
    # nothing to strip
    assert clean_title("MSc Computer Science", "") == "MSc Computer Science"
    assert clean_title("Online MSc Computer Science, Modules, Careers",
                       "Abertay") == "Online MSc Computer Science, Modules, Careers"


# ========================================= finding the supporting sentence
def test_a_paraphrased_money_fact_finds_its_real_sentence():
    """Pages write money with separators and symbols; models report digits.

    Searching the page for the literal digits meant "24500" was looked up
    on a page saying "GBP 24,500", no sentence was found, and the field
    was dropped as unbacked. Every tuition and award amount was lost this
    way, on every page, whatever the page said.
    """
    from app.core.evidence import find_evidence
    from app.tools.fetch import sentences

    page = (
        "MSc Computer Science. Tuition for international students is "
        "GBP 24,500 for the full programme. Applicants need IELTS 6.5 "
        "overall. The deadline to apply is 15 January 2027."
    )
    lines = list(sentences(page))

    assert "24,500" in find_evidence(24500, lines)
    assert "24,500" in find_evidence(24500.0, lines)
    assert "IELTS 6.5" in find_evidence(6.5, lines)
    # an ISO date against a page that writes it out in words
    assert "15 January 2027" in find_evidence("2027-01-15", lines)

    # and a value the page does not state finds nothing, as it must
    assert find_evidence(99999, lines) == ""
    assert find_evidence("2030-03-01", lines) == ""


def test_the_quote_and_the_search_apply_the_same_test():
    """Two definitions of "supported" is one definition too many.

    is_backed checked the model's quote with number renderings while the
    page search used a plain substring, so a fact could fail the search
    that would have passed the check.
    """
    from app.core.evidence import ExtractedField, is_backed, sentence_supports

    sentence = "Tuition for international students is GBP 24,500 per year."

    ok, _ = sentence_supports(24500, sentence)
    assert ok

    backed, _ = is_backed(ExtractedField(
        name="tuition", value=24500, evidence=sentence,
        source_url="https://x.ac.uk/c",
    ))
    assert backed is ok


# ====================================================== talking to providers
def test_a_rate_limit_is_waited_out_for_as_long_as_it_asked():
    """A 429 says how long to wait. Guessing loses the page.

    Groq rate-limited one page in four during a live run. The backoff
    waited one second then two and gave up, while the response header
    had said exactly how long it needed.
    """
    from app.providers.http_llm import _retry_after

    class Response:
        def __init__(self, value):
            self.headers = {} if value is None else {"retry-after": value}

    assert _retry_after(Response("7"), 1.0) == 7.0
    assert _retry_after(Response("7.5"), 1.0) == 7.5
    assert _retry_after(Response("7s"), 1.0) == 7.0

    # no header, or one we cannot read: keep our own backoff
    assert _retry_after(Response(None), 1.0) == 1.0
    assert _retry_after(Response(""), 2.0) == 2.0
    assert _retry_after(Response("bogus"), 2.0) == 2.0

    # a provider having a bad day must not hold a student's request open
    assert _retry_after(Response("999"), 1.0) == 15.0
    assert _retry_after(Response("1m30s"), 1.0) == 15.0


def test_a_connection_that_never_completed_is_worth_asking_again():
    """A 404 is an answer. A timeout is not.

    The best scholarship result of a live run - Nottingham's Developing
    Solutions award - was lost to a single ConnectTimeout, and the time
    it burned stopped the rest of the run. Retrying a page that answered
    would be both rude and pointless, so only connection failures count.
    """
    from app.tools.fetch import is_transient

    assert is_transient("ConnectTimeout")
    assert is_transient("ReadTimeout")
    assert is_transient("ConnectError")
    assert is_transient("RemoteProtocolError")

    # these are answers, not failures to reach
    assert not is_transient("HTTPStatusError")
    assert not is_transient("TooManyRedirects")
    assert not is_transient("UnsupportedProtocol")
    assert not is_transient("")


def test_an_article_url_costs_nothing_to_reject():
    """The address is known before the page is read. Use it then.

    A KCL help-desk article was fetched, sent to the model, extracted,
    and only then rejected for sitting under /article/ - in a scholarship
    run that ran out of time two pages in, with real award pages still
    unread.
    """
    import asyncio

    from app.tools.extract import extract_from_page
    from app.tools.fetch import Page

    called = {"n": 0}

    class CountingLLM:
        name = "stub"

        async def complete_json(self, system, user, schema=None, **kw):
            called["n"] += 1
            return {"found": True, "title": "x", "university": "y"}

    article = Page(
        url="https://self-service.kcl.ac.uk/article/KA-01819/en-us",
        status=200,
        text="Entry requirements and tuition fees are explained here. " * 20,
        content_hash="a",
    )
    out = asyncio.run(extract_from_page(CountingLLM(), article, kind="scholarship"))
    assert out.found is False
    assert called["n"] == 0, "an article URL must not reach the model"

    # a real award page is unaffected
    award = Page(
        url="https://www.nottingham.ac.uk/pgstudy/funding/developing-solutions",
        status=200,
        text="Entry requirements and tuition fees are explained here. " * 20,
        content_hash="b",
    )
    asyncio.run(extract_from_page(CountingLLM(), award, kind="scholarship"))
    assert called["n"] == 1