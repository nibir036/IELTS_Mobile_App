"""One error shape for the whole API.

The error codes match what the Flutter app already handles, so the existing
client-side handling keeps working when Node proxies to this service.
"""
from __future__ import annotations


class AppError(Exception):
    status_code = 500
    code = "internal_error"
    message = "Something went wrong on our side. Please try again."

    def __init__(self, message: str | None = None, **extra) -> None:
        if message:
            self.message = message
        self.extra = extra
        super().__init__(self.message)

    def body(self) -> dict:
        out = {"code": self.code, "message": self.message}
        out.update(self.extra)
        return out


class NotAuthenticated(AppError):
    status_code = 401
    code = "not_authenticated"
    message = "Sign in again to continue."


class MissingField(AppError):
    status_code = 400
    code = "missing_field"
    message = "A required field was empty."


class NotFound(AppError):
    """Also used for 'not yours' - deliberately indistinguishable."""

    status_code = 404
    code = "not_found"
    message = "Not found."


class AiLimitReached(AppError):
    status_code = 429
    code = "ai_limit_reached"
    message = "You have used today's AI searches. They reset at midnight."


class AiNotConfigured(AppError):
    status_code = 503
    code = "ai_not_configured"
    message = "The counsellor is not available right now."


class AiBusy(AppError):
    status_code = 503
    code = "ai_busy"
    message = "The counsellor is busy right now. Please try again in a moment."


class AiFailed(AppError):
    status_code = 502
    code = "ai_failed"
    message = "The counsellor could not finish that. Please try again."
