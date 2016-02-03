#!/bin/bash

EXTERNAL_HOST="${EXTERNAL_HOST:-localhost}"
EXTERNAL_PORT="${EXTERNAL_PORT:-80}"
HTTPS_ENABLED="${HTTPS_ENABLED:-False}"
SETTING_EMAIL_BACKEND="${SETTING_EMAIL_BACKEND:-django.core.mail.backends.smtp.EmailBackend}"
SETTING_CELERY_RESULT_BACKEND=""
DB_HOST="${DB_HOST:-database}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-taigaio}"
DB_USER="${DB_USER:-taigaio}"
DB_PASS="${DB_PASS:-taigaio}"
RABBITMQ_HOST="${RABBITMQ_HOST:-rabbitmq}"
RABBITMQ_HOST_PORT="${RABBITMQ_HOST_PORT:-5672}"
RABBITMQ_VHOST="${RABBITMQ_VHOST:-taiga}"
RABBITMQ_USER="${RABBITMQ_USER:-taiga}"
RABBITMQ_PASS="${RABBITMQ_PASS:-taiga}"
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_HOST_PORT="${REDIS_HOST_PORT:-6379}"

LOCAL_PY="/opt/taiga/taiga-back/settings/local.py"

setConfigurationValue() {
    if [ -z "$1" ]; then
        echo "No KEY given for setConfigurationValue."
        return 1
    fi
    if [ -z "$3" ]; then
        echo "No FILE given for setConfigurationValue."
        return 1
    fi
    local KEY="$1"
    local VALUE
    local FILE="$3"
    local TYPE="$4"
    if [ -z "$TYPE" ]; then
        case "$2" in
            [Tt][Rr][Uu][Ee]|[Ff][Aa][Ll][Ss][Ee])
            TYPE="bool"
            ;;
            *)
            TYPE="string"
            ;;
        esac
    fi
    case "$TYPE" in
        emptyreturn)
        if [ -z "$2" ]; then
            return 0
        fi
        ;;
        literal)
        VALUE="$1"
        ;;
        bool|boolean|int|integer|array)
        VALUE="$KEY = $2"
        ;;
        string|*)
        VALUE="$KEY = '${2//\'/\'}'"
        ;;
    esac
    echo "$VALUE" >> "$FILE"
    echo "+ Setting key \"$KEY\", type \"$TYPE\" in file \"$FILE\"."
}
taigaConfiguration() {
    if [ "$HTTPS_ENABLED" == "True" ] || [ "$HTTPS_ENABLED" == "true" ]; then
        local SCHEMA="https"
    else
        local SCHEMA="http"
    fi
    echo "" > "$LOCAL_PY"
    # TODO Add support for themes and that stuff
    mkdir -p /opt/taiga/taiga-front/dist
cat <<EOF > /opt/taiga/taiga-front/dist/conf.json
{
    "api": "$SCHEMA://$EXTERNAL_HOST:$EXTERNAL_PORT/api/v1/",
    "eventsUrl": "ws://$EXTERNAL_HOST:8888/events",
    "eventsMaxMissedHeartbeats": 5,
    "eventsHeartbeatIntervalTime": 60000,
    "debug": $(echo $SETTING_DEBUG | tr '[:upper:]' '[:lower:]'),
    "debugInfo": false,
    "defaultLanguage": "en",
    "themes": ["taiga"],
    "defaultTheme": "taiga",
    "publicRegisterEnabled": true,
    "feedbackEnabled": true,
    "privacyPolicyUrl": null,
    "termsOfServiceUrl": null,
    "maxUploadFileSize": null,
    "contribPlugins": []
}
EOF
cat <<EOF > /opt/taiga/taiga-events/config.json
{
"url": "amqp://$RABBITMQ_USER:$RABBITMQ_PASS@$RABBITMQ_HOST:$RABBITMQ_HOST_PORT/$RABBITMQ_VHOST",
"secret": "mysecret",
"webSocketServer": {
    "port": 8888
}
}
EOF
    chown taiga: -R "$LOCAL_PY" /opt/taiga/taiga-events/config.json /opt/taiga/taiga-front/dist
    local VALUE="{
    'default': {
        'ENGINE': 'transaction_hooks.backends.postgresql_psycopg2',
        'NAME': '$DB_NAME',
        'USER': '$DB_USER',
        'PASSWORD': '$DB_PASS',
        'HOST': '$DB_HOST',
        'PORT': '$DB_PORT',
    }
}"
    setConfigurationValue "from .development import *" "" "$LOCAL_PY" "literal"
    setConfigurationValue "from .celery import *" "" "$LOCAL_PY" "literal"
    setConfigurationValue "DATABASES" "$VALUE" "$LOCAL_PY" "array"
    setConfigurationValue "CELERY_ENABLED" "True" "$LOCAL_PY"
    setConfigurationValue "CELERY_RESULT_BACKEND" "redis://$REDIS_HOST:$REDIS_HOST_PORT/0" "$LOCAL_PY"
    setConfigurationValue "BROKER_URL" "amqp://$RABBITMQ_USER:$RABBITMQ_PASS@$RABBITMQ_HOST:$RABBITMQ_HOST_PORT//" "$LOCAL_PY"
    setConfigurationValue "EVENTS_PUSH_BACKEND" "taiga.events.backends.rabbitmq.EventsPushBackend" "$LOCAL_PY"
    setConfigurationValue "EVENTS_PUSH_BACKEND_OPTIONS" "{\"url\": \"amqp://$RABBITMQ_USER:$RABBITMQ_PASS@$RABBITMQ_HOST:$RABBITMQ_HOST_PORT/$RABBITMQ_VHOST\"}" "$LOCAL_PY" "array"
    unset SETTING_EVENTS_PUSH_BACKEND SETTING_EVENTS_PUSH_BACKEND_OPTIONS SETTINGS_BROKER_URL SETTING_CELERY_RESULT_BACKEND
    setConfigurationValue "MEDIA_URL" "http://$EXTERNAL_HOST/media/" "$LOCAL_PY"
    setConfigurationValue "STATIC_URL" "http://$EXTERNAL_HOST/static/" "$LOCAL_PY"
    setConfigurationValue "ADMIN_MEDIA_PREFIX" "http://$EXTERNAL_HOST/static/admin/" "$LOCAL_PY"
    if [ "$FRONT_SITEMAP_ENABLED" != "True" ] || [ "$FRONT_SITEMAP_ENABLED" == "true" ]; then
        setConfigurationValue "FRONT_SITEMAP_ENABLED" "True" "$LOCAL_PY"
        setConfigurationValue "FRONT_SITEMAP_CACHE_TIMEOUT" "60*60" "$LOCAL_PY" "array"
    fi
    local SUPERUSERS="ADMINS = ("
    echo "$ADMIN_USERS" | sed -n 1'p' | tr ';' '\n' | while read ADMIN_USER; do
        SUPERUSERS="$SUPERUSERS\n    $ADMIN_USER,"
    done
    setConfigurationValue "$SUPERUSERS)" "" "$LOCAL_PY" "literal"
    SET_SETTINGS=($(env | sed -n -r "s/SETTING_([0-9A-Za-z_]*).*/\1/p"))
    for SETTING_KEY in "${SET_SETTINGS[@]}"; do
        KEY="SETTING_$SETTING_KEY"
        SETTING_VAR="${!KEY}"
        if [ -z "$SETTING_VAR" ]; then
            echo "Empty var for key \"$SETTING_KEY\"."
            continue
        fi
        setConfigurationValue "$SETTING_KEY" "$SETTING_VAR" "$LOCAL_PY"
    done
    unset SETTING_KEY SETTING_VAR KEY
}
configureHttps() {
    if [ "$HTTPS_ENABLED" == "True" ] || [ "$HTTPS_ENABLED" == "true" ]; then
        mv /includes/taiga-https /etc/nginx/sites-enabled/taiga
        sed -i 's|http://|https://|g' /opt/taiga/taiga-front/dist/conf.json
        sed -i 's|http://|https://|g' "$LOCAL_PY"
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
rabbitmqSetup() {
    rabbitmqctl -n "$RABBITMQ_USER@$RABBITMQ_HOST" delete_user guest 2> /dev/null || :
    rabbitmqctl -n "$RABBITMQ_USER@$RABBITMQ_HOST" add_user "$RABBITMQ_USERNAME" "$RABBITMQ_PASS" 2> /dev/null || :
    rabbitmqctl -n "$RABBITMQ_USER@$RABBITMQ_HOST" set_user_tags "$RABBITMQ_USER" administrator 2> /dev/null || :
    rabbitmqctl -n "$RABBITMQ_USER@$RABBITMQ_HOST" set_permissions -p / "$RABBITMQ_USER" '.*' '.*' '.*' || :
    rabbitmqctl -n "$RABBITMQ_USER@$RABBITMQ_HOST" add_vhost /taiga || :
    rabbitmqctl -n "$RABBITMQ_USER@$RABBITMQ_HOST" set_permissions -p /taiga "$RABBITMQ_USER" '.*' '.*' '.*' || :
}
runMigration() {
    su taiga -c "source /opt/taiga/.virtualenvs/taiga/bin/activate;cd /opt/taiga/taiga-back;python /opt/taiga/taiga-back/manage.py migrate --noinput"
    if [ ! -z "$INSERT_DEFAULT_DATA" ] && ([ "$INSERT_DEFAULT_DATA" == "True" ] || [ "$INSERT_DEFAULT_DATA" == "true" ]); then
        su taiga -c "source /opt/taiga/.virtualenvs/taiga/bin/activate;cd /opt/taiga/taiga-back;python /opt/taiga/taiga-back/manage.py loaddata initial_user"
        su taiga -c "source /opt/taiga/.virtualenvs/taiga/bin/activate;cd /opt/taiga/taiga-back;python /opt/taiga/taiga-back/manage.py loaddata initial_project_templates"
        su taiga -c "source /opt/taiga/.virtualenvs/taiga/bin/activate;cd /opt/taiga/taiga-back;python /opt/taiga/taiga-back/manage.py loaddata initial_role"
        su taiga -c "source /opt/taiga/.virtualenvs/taiga/bin/activate;cd /opt/taiga/taiga-back;python /opt/taiga/taiga-back/manage.py compilemessages"
    fi
    su taiga -c "source /opt/taiga/.virtualenvs/taiga/bin/activate;cd /opt/taiga/taiga-back;python /opt/taiga/taiga-back/manage.py collectstatic --noinput"
}
generateFrontFiles() {
    su taiga -c "cd /opt/taiga/taiga-front;gulp deploy"
}

configureHttps
taigaConfiguration
databaseSetup
rabbitmqSetup
runMigration
generateFrontFiles

exec supervisord -n
