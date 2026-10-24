"""What the counsellor says, and when it offers the office.

Plain Python so it can be tested without a model. The fee reply in
particular is a fixed string: if the model produced it, paraphrasing drift
would be invisible and untestable.
"""
from __future__ import annotations

import re
from enum import Enum

# The approved file-opening fee reply. Do not reword - there is a test that
# asserts this exact text.
FEE_RESPONSE = (
    "You can get the answer to your query from our office. Please contact "
    "us at {phone}, or visit our office in Banani, Dhaka."
)


def fee_response(phone: str) -> str:
    """nextED's own fees, costs or charges: the office answers, never the AI
    (left to itself it told a student the service was "completely free")."""
    return FEE_RESPONSE.format(phone=phone or "our office number")

DOCUMENT_GUIDANCE = (
    "In general, most applications ask for some combination of: a passport, "
    "academic certificates and transcripts, an English test result where one "
    "is required, a CV where the programme asks for one, and a statement of "
    "purpose or research proposal for many postgraduate courses.\n\n"
    "The exact list changes by country, by university, by programme, by "
    "degree level and by which stage you are at - and admission documents, "
    "scholarship documents and visa documents are three different sets. "
    "Please treat this as a general idea rather than a checklist.\n\n"
    "Getting this exactly right is what our counsellors at nextED do every "
    "day: they put together the real list for your university and your stage, "
    "and check every document with you before it goes in. Come to nextED and "
    "we will build your file together."
)


def contact_response(name: str, phone: str, address: str, maps_url: str) -> str:
    """The reply to "how do I reach a counsellor?" - fixed, never the model.

    Only the ways that really exist. The model, left to itself, offered
    in-app booking, a callback and an email address - none of which nextED
    has. So this answer is assembled from the office settings and nothing
    else.
    """
    name = name or "nextED"
    lines = [f"You can talk to a {name} counsellor directly:", ""]
    if phone:
        lines.append(f"- Call us on {phone}")
    if address:
        lines.append(f"- Visit our office: {address}")
    if maps_url:
        lines.append("- The buttons below call the office or open directions")
    lines += [
        "",
        "Bring your questions about countries, universities, scholarships, "
        "applications or visas - and your academic documents if you have them "
        "handy. Meanwhile, I can help you here with your options, your profile "
        "and the next steps.",
    ]
    return "\n".join(lines)


class Intent(str, Enum):
    fee_question = "fee_question"
    contact_request = "contact_request"
    document_checklist = "document_checklist"
    admission_chance = "admission_chance"
    find_universities = "find_universities"
    general = "general"


# nextED's own fees, costs, charges or "is it free" - however it is asked.
_FEE = [
    r"\b(cost|costs|price|pricing|fee|fees|charge|charges|pay|paying|payment|free|money|taka|tk|bdt|package)\b.{0,40}\b(nexted|your (service|services|team|office|company|agency|consultancy|help)|working with (you|nexted)|work with (you|nexted)|using (you|nexted))\b",
    r"\b(nexted|your (service|services|consultancy|agency|company))\b.{0,30}\b(cost|costs|price|pricing|fee|fees|charge|charges|free|package|payment|pay)\b",
    r"\b(is|are) (it|this|your service|your services|nexted|you) (free|paid)\b",
    r"\bdo (i|we) (have|need) to pay (you|nexted|anything)\b",
    r"\bhow much (do|does|will) (you|nexted)\b",
    r"(নেক্সটেড|আপনাদের|আপনার).{0,20}(খরচ|ফি|চার্জ|টাকা)",
    r"(খরচ|ফি|চার্জ|টাকা).{0,20}(নেক্সটেড|আপনাদের)",
    r"\bfile[- ]?open(ing)?\b.{0,20}\b(fee|charge|cost|price|money|taka|tk)\b",
    r"\b(fee|charge|cost|price)\b.{0,25}\bfile\b",
    r"\byour\b.{0,15}\b(service|consultancy|agency)\b.{0,15}\b(fee|charge|cost)\b",
    r"\bhow much\b.{0,30}\b(you|nexted|your office)\b.{0,20}\b(charge|cost|fee)\b",
    r"কত\b.{0,20}\b(ফি|চার্জ|টাকা)\b",
]
_DOCS = [
    r"\b(full|complete|entire|whole|all)\b.{0,20}\b(document|checklist|papers?)\b",
    r"\b(document|paper)s?\b.{0,15}\b(checklist|list|required|need)\b",
    r"\bwhat documents\b",
]
_CHANCE = [
    r"\b(chance|chances|odds|probability|likelihood)\b",
    r"\bwill i (get|be) (in|admitted|accepted)\b",
    r"\bcan i get (into|admission|in(?! touch))\b",
    r"\bam i (eligible|qualified)\b",
]
# "How do I reach a person at nextED?" - however it is worded. Kept to
# phrasings about reaching nextED itself, so "the number of universities" or
# "should I contact the university" do not trigger the fixed contact reply.
_CONTACT = [
    r"\b(talk|speak|meet|chat|connect)\b.{0,25}\b(counsel+or|advis[eo]r|consultant|someone|somebody|a person|a human|an agent|nexted|your team|your office|you)\b",
    r"\b(get|be|stay|keep) in touch\b",
    r"\b(call|phone|ring|whatsapp|text|message|e-?mail)\b.{0,6}\bme\b",
    r"\b(contact|reach|call|phone|ring|whatsapp|e-?mail|message)\b.{0,25}\b(you|nexted|counsel+or|office|your team|advis[eo]r|consultant)\b",
    r"\b(counsel+or|consultant|advis[eo]r)\b.{0,30}\b(contact|reach|talk|speak|meet|call|appointment|book|available)\b",
    r"\b(book|schedule|arrange|make|get|fix|set up)\b.{0,20}\b(appointment|consultation|meeting|session)\b",
    r"\b(appointment|consultation)\b",
    r"\b(where|what)\b.{0,20}\b(office|address|located|location)\b",
    r"\b(your|nexted'?s?)\b.{0,12}\b(phone|number|contact|address|e-?mail|whatsapp|office|hotline)\b",
    r"\b(map|directions?)\b.{0,20}\b(office|you|nexted)\b",
    r"\bvisit\b.{0,15}\b(office|you|nexted)\b",
    r"(কাউন্সেলর|কাউন্সিলর|যোগাযোগ|অফিস|ঠিকানা|ফোন নম্বর|নাম্বার)",
]
_FIND = [
    r"\b(universit|college|program|programme|course)\w*\b",
    r"\b(suggest|recommend|shortlist|options)\b",
    r"\b(deadline|intake|scholarship|admission)\b",
]


# Costs that belong to someone else (the university, the embassy, rent).
_THIRD_PARTY = r"\b(tuition|university|universities|uni|college|living|accommodation|rent|visa|embassy|ihs|health surcharge|ielts|toefl|pte|duolingo|application fee|deposit|flight|ticket|insurance)\b"
_NAMES_NEXTED = r"\b(nexted|file[- ]?open|service charge|service fee|consultancy|your service|your services|your fee|your fees|your charge|working with (you|nexted))\b"


def _third_party_cost(text: str) -> bool:
    low = text.lower()
    return bool(re.search(_THIRD_PARTY, low)) and not re.search(_NAMES_NEXTED, low)


def _any(patterns: list[str], text: str) -> bool:
    low = text.lower()
    return any(re.search(p, low) for p in patterns)


def classify_intent(message: str) -> Intent:
    """Narrow, must-not-improvise cases first."""
    if not message:
        return Intent.general
    if _any(_FEE, message) and not _third_party_cost(message):
        return Intent.fee_question
    if _any(_DOCS, message):
        return Intent.document_checklist
    if _any(_CHANCE, message):
        return Intent.admission_chance
    if _any(_CONTACT, message):
        return Intent.contact_request
    if _any(_FIND, message):
        return Intent.find_universities
    return Intent.general


_INVITATION = {
    Intent.admission_chance: (
        "I can tell you what a programme asks for, but a realistic read on "
        "your chances needs someone looking at your actual transcript. That is "
        "exactly what our counsellors at nextED do: they go through your "
        "results with you and tell you where you stand and where to apply. "
        "Come to nextED and we will plan your applications together."
    ),
}


def invitation_for(intent) -> str:
    """One invitation, only on a real trigger.

    Never appended to every message: students learn to skip it within three
    messages, and then the real invitations stop landing too. The fee and
    document replies already contain their own offer, so they get none here.
    """
    return _INVITATION.get(intent, "")
