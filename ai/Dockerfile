# nextED AI service (AI Counsellor, Course Finding, Scholarship Finding) -
# for Coolify (or any Docker host). Build context = this folder (ai/).
#
# Private: only the API server calls it. Give it NO domain in Coolify; the
# API reaches it over Coolify's internal network (NEXTED_AI_URL in the API).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    APP_ENV=production \
    DATA_DIR=/app/data \
    RESTRICTIONS_FILE=/app/data/restrictions.json \
    PORT=8000

WORKDIR /app

# Dependencies first (cached between deploys while requirements.txt is unchanged).
COPY requirements.txt ./
RUN pip install -r requirements.txt

COPY . .

# What the service learns (catalogue write-back, usage) lives here: mount a
# persistent volume at /app/data in Coolify, or it is lost on every redeploy.
# The real restriction list goes in the same volume as restrictions.json;
# until it is there, restriction checking is off (never the 4 sample rules).
RUN mkdir -p /app/data
VOLUME ["/app/data"]

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD python -c "import os,urllib.request,sys; urllib.request.urlopen('http://127.0.0.1:'+os.environ.get('PORT','8000')+'/health', timeout=4); sys.exit(0)" || exit 1

# APP_ENV=production: the service refuses to start without SERVICE_TOKEN.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
