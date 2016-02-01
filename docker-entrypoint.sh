#!/bin/bash

HTTPS_ENABLED="${HTTPS_ENABLED:-False}"


python manage.py migrate --noinput
if [ ! -f "$DATA_DIR/initiated" ]; then
    python manage.py loaddata initial_user
    python manage.py loaddata initial_project_templates
    python manage.py loaddata initial_role
fi
python manage.py compilemessages
python manage.py collectstatic --noinput
