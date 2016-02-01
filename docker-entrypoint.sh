#!/bin/bash

LOCAL_PY="/home/taiga/taiga-back/settings/local.py"

EXTERNAL_HOST="${EXTERNAL_HOST:-localhost}"
HTTPS_ENABLED="${HTTPS_ENABLED:-False}"
SETTING_EMAIL_BACKEND="${SETTING_EMAIL_BACKEND:-django.core.mail.backends.smtp.EmailBackend}"
SETTING_CELERY_RESULT_BACKEND=""
DB_HOST="${DB_HOST:-database}"
DB_NAME="${DB_NAME:-taigaio}"
DB_USER="${DB_USER:-taigaio}"
DB_PASS="${DB_PASS:-taigaio}"
RABBITMQ_HOST="${RABBITMQ_HOST:-rabbitmq}"
RABBITMQ_PORT="${RABBITMQ_PORT:-5672}"
RABBITMQ_USER="${RABBITMQ_USER:-taiga}"
RABBITMQ_PASS="${RABBITMQ_PASS:-taiga}"
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"

taigaConfiguration() {
cat <<EOF >> /home/taiga/taiga-front-dist/dist/conf.json
{
    "api": "http://example.com/api/v1/",
    "eventsUrl": "ws://example.com/events",
    "debug": "true",
    "publicRegisterEnabled": true,
    "feedbackEnabled": true,
    "privacyPolicyUrl": null,
    "termsOfServiceUrl": null,
    "maxUploadFileSize": null,
    "contribPlugins": []
}
EOF
cat <<EOF >> "$LOCAL_PY"
DATABASES = {
        'default': {
            'ENGINE': 'transaction_hooks.backends.postgresql_psycopg2',
            'NAME': '$DB_NAME',
            'USER': '$DB_USER',
            'PASSWORD': '$DB_PASS',
            'HOST': '$DB_HOST',
            'PORT': '$DB_PORT',
        }
    }
}
EOF
echo "CELERY_RESULT_BACKEND = 'redis://$REDIS_HOST:$REDIS_PORT/0'" >> "$LOCAL_PY"
echo "BROKER_URL = 'amqp://$RABBITMQ_USER:$RABBITMQ_PASS@$RABBITMQ_HOST:$RABBITMQ_PORT//'" >> "$LOCAL_PY"
echo "EVENTS_PUSH_BACKEND_OPTIONS = {\"url\": \"amqp://$RABBITMQ_USER:$RABBITMQ_PASS@$RABBITMQ_HOST:$RABBITMQ_PORT/taiga\"}" >> "$LOCAL_PY"
unset SETTING_EVENTS_PUSH_BACKEND_OPTIONS SETTINGS_BROKER_URL SETTING_CELERY_RESULT_BACKEND
cat <<EOF >> /home/taiga/taiga-events/config.json
{
    \"url\": \"amqp://$RABBITMQ_USER:$RABBITMQ_PASS@$RABBITMQ_HOST:$RABBITMQ_PORT/taiga\",
    \"secret\": \"mysecret\",
    \"webSocketServer\": {
        \"port\": 8888
    }
}
EOF
cat <<EOF >> "$LOCAL_PY"
MEDIA_URL = "http://$EXTERNAL_HOST/media/"
STATIC_URL = "http://$EXTERNAL_HOST/static/"
ADMIN_MEDIA_PREFIX = "http://$EXTERNAL_HOST/static/admin/"
SITES["front"]["domain"] = "$EXTERNAL_HOST"
EOF
if [ ! -z "$FRONT_SITEMAP_ENABLED" ]; then
    echo "FRONT_SITEMAP_ENABLED = $FRONT_SITEMAP_ENABLED" >> "$LOCAL_PY"
    echo "FRONT_SITEMAP_CACHE_TIMEOUT = 60*60" >> "$LOCAL_PY"
fi
echo "ADMINS = (" >> "$LOCAL_PY"
echo "$ADMIN_USERS" | sed -n 1'p' | tr ';' '\n' | while read ADMIN_USER; do
    echo "$ADMIN_USER," > "$LOCAL_PY"
done
echo ")" >> "$LOCAL_PY"
SET_SETTINGS=($(env | sed -n -r "s/SETTING_([0-9A-Za-z_]*).*/\1/p"))
for SETTING_KEY in "${SET_SETTINGS[@]}"; do
    KEY="ZULIP_SETTINGS_$SETTING_KEY"
    SETTING_VAR="${!KEY}"
    if [ -z "$SETTING_VAR" ]; then
        echo "Empty var for key \"$SETTING_KEY\"."
        continue
    fi
    setConfigurationValue "$SETTING_KEY" "$SETTING_VAR" "$FILE"
done
unset SETTING_KEY SETTING_VAR KEY
}
configureHttps() {
    echo "SITES[\"front\"][\"scheme\"] = \"https\"" >> "$LOCAL_PY"
    if [ "$HTTPS_ENABLED" != "False" ] && [ "$HTTPS_ENABLED" != "false" ]; then
        mv /includes/taiga-https /etc/nginx/sites-enabled/taiga
        sed -i 's|http://|https://|g' /home/taiga/taiga-front-dist/dist/conf.json
        sed -i 's|http://|https://|g' "$LOCAL_PY"
        echo "SITES[\"front\"][\"scheme\"] = \"https\"" >> "$LOCAL_PY"
    fi
}
databaseSetup() {
    export PGPASSWORD="$DB_PASS"
    local TIMEOUT=45
    echo "Waiting for database server to allow connections ..."
    while ! /usr/bin/pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -t 1 >/dev/null 2>&1
    do
        TIMEOUT=$(expr $TIMEOUT - 1)
        if [[ $TIMEOUT -eq 0 ]]; then
            echo "Could not connect to database server. Exiting."
            exit 1
        fi
        echo -n "."
        sleep 1
    done
    echo """
    CREATE USER $DB_USER;
    ALTER ROLE $DB_USER SET search_path TO $DB_NAME,public;
    CREATE DATABASE $DB_NAME OWNER=$DB_USER;
    CREATE SCHEMA $DB_SCHEMA AUTHORIZATION $DB_USER;
    """ | psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" || :
}
runMigration() {
    su taiga -c "python /home/taiga/taiga-back/manage.py migrate --noinput"
    if [ ! -f "$DATA_DIR/initiated" ]; then
        su taiga -c "python /home/taiga/taiga-back/manage.py loaddata initial_user"
        su taiga -c "python /home/taiga/taiga-back/manage.py loaddata initial_project_templates"
        su taiga -c "python /home/taiga/taiga-back/manage.py loaddata initial_role"
    fi
    su taiga -c "python /home/taiga/taiga-back/manage.py compilemessages"
    su taiga -c "python /home/taiga/taiga-back/manage.py collectstatic --noinput"
}
configureHttps
taigaConfiguration
databaseSetup
runMigration

supervisord -n
