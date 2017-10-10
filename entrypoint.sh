#! /bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}/symmetric-server"

# Environment variables
LISTEN_HOST="${LISTEN_HOST:-0.0.0.0}"
LISTEN_PORT="${LISTEN_PORT}"
HTTPS="${HTTPS:-TRUE}"
GROUP_ID="${GROUP_ID:-GROUP_ID}"
ENGINE_NAME="${ENGINE_NAME:-${GROUP_ID}}"
EXTERNAL_ID="${EXTERNAL_ID:-${GROUP_ID}}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT}"
DB_TYPE="${DB_TYPE:-postgres}"
DB_NAME="${DB_NAME:-DB_NAME}"
DB_USER="${DB_USER:-DB_USER}"
DB_PASS="${DB_PASS:-DB_PASS}"
SYNC_URL="${SYNC_URL}"
REGISTRATION_URL="${REGISTRATION_URL}"
REPLICATE_TO="${REPLICATE_TO}"
REPLICATE_TABLE="${REPLICATE_TABLE}"

# Build other variables
HTTP_ENABLE="false"
HTTP_PORT="31415"
HTTPS_ENABLE="false"
HTTPS_PORT="31417"

if [ "${HTTPS}" == "FALSE" ]; then
  HTTP_ENABLE="true"
  HTTP_PORT="${LISTEN_PORT:-${HTTP_PORT}}"
else
  LISTEN_PORT="${LISTEN_PORT:-31417}"
  HTTPS_ENABLE="true"
  HTTPS_PORT="${LISTEN_PORT:-${HTTPS_PORT}}"
fi

case "${DB_TYPE}" in
  "mysql")
    DB_PORT="${DB_PORT:-3306}"
    DB_CMD="mysql -h \"${DB_HOST}\" -P \"${DB_POST}\" -u \"${DB_USER}\" -p\"${DB_PASS}\" \"${DB_NAME}\""
    JDBC_DRIVER="com.mysql.jdbc.Driver"
    JDBC_URL="jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
    echo "Warning: There appears to be a bug in MySQL support."
    ;;
  "oracle")
    DB_PORT="${DB_PORT:-1521}"
    DB_CMD="sqlplus64 \"${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_NAME}\""
    JDBC_DRIVER="oracle.jdbc.driver.OracleDriver"
    JDBC_URL="jdbc:oracle:thin:@${DB_HOST}:${DB_PORT}:${DB_NAME}"
    echo "Warning: Some docker images of Oracle will listen to their port before they are ready to accept connections which will break this image."
    ;;
  "postgres")
    DB_PORT="${DB_PORT:-5432}"
    DB_CMD="PGPASSWORD=\"${DB_PASS}\" psql -w -h \"${DB_HOST}\" -p \"${DB_POST}\" \"${DB_NAME}\" \"${DB_USER}\""
    JDBC_DRIVER="org.postgresql.Driver"
    JDBC_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
    ;;
esac

# Configure according to environment variables
cat << EOL > "./conf/symmetric-server.properties"
host.bind.name=${LISTEN_HOST}
http.enable=${HTTP_ENABLE}
http.port=${HTTP_PORT}
https.enable=${HTTPS_ENABLE}
https.port=${HTTPS_PORT}
https.allow.self.signed.certs=true
https.verified.server.names=all
jmx.http.enable=false
jmx.http.port=31416
EOL

cat << EOL > "./engines/${ENGINE_NAME}-${EXTERNAL_ID}.properties"
engine.name=${ENGINE_NAME}
group.id=${GROUP_ID}
external.id=${EXTERNAL_ID}
sync.url=${SYNC_URL}
registration.url=${REGISTRATION_URL}
db.driver=${JDBC_DRIVER}
db.url=${JDBC_URL}
db.user=${DB_USER}
db.password=${DB_PASS}
EOL

if [[ ! -z "${REPLICATE_TO}" ]]; then
  cat << EOL >> "./engines/${ENGINE_NAME}-${EXTERNAL_ID}.properties"
initial.load.create.first=true
EOL
fi

echo "Waiting for database at ${DB_HOST}:${DB_PORT}..."
nc="nc ${DB_HOST} ${DB_PORT} </dev/null 2>/dev/null"
set +e
eval ${nc}
while [ $? -ne 0 ]; do
  echo ...
  sleep 5
  eval ${nc}
done

if [[ ! -z "${REPLICATE_TO}" ]]; then
  echo "Initialising config in ${DB_TYPE}..."
  cat << EOL > "init.sql"
insert into sym_node_group
        (node_group_id)
        values ('${REPLICATE_TO}');

insert into sym_node_group_link
(source_node_group_id, target_node_group_id, data_event_action)
      values ('${REPLICATE_TO}', '${GROUP_ID}', 'P');

insert into sym_node_group_link
(source_node_group_id, target_node_group_id, data_event_action)
      values ('${GROUP_ID}', '${REPLICATE_TO}', 'W');

insert into sym_router (router_id,
        source_node_group_id, target_node_group_id, create_time,
        last_update_time) values ('${GROUP_ID}-2-${REPLICATE_TO}','${GROUP_ID}', '${REPLICATE_TO}',
        current_timestamp, current_timestamp);

insert into sym_channel (channel_id, processing_order, max_batch_size, max_batch_to_send,
         extract_period_millis, batch_algorithm, enabled)
     values ('${REPLICATE_TABLE}', 10, 1000, 10, 0, 'default', 1);

insert into sym_trigger (trigger_id, source_table_name,
          channel_id, last_update_time, create_time)
                  values ('${REPLICATE_TABLE}', '${REPLICATE_TABLE}', '${REPLICATE_TABLE}', current_timestamp, current_timestamp);

insert into sym_trigger_router
        (trigger_id, router_id, initial_load_order, create_time,
        last_update_time) values ('${REPLICATE_TABLE}', '${GROUP_ID}-2-${REPLICATE_TO}', 1, current_timestamp,
        current_timestamp);

EOL

  ./bin/symadmin --engine "${GROUP_ID}" create-sym-tables
  ./bin/dbimport --engine "${GROUP_ID}" "init.sql"
  rm "init.sql"
  echo "Opening registration for '${REPLICATE_TO}'..."
  ./bin/symadmin --engine "${GROUP_ID}" open-registration "${REPLICATE_TO}" "${REPLICATE_TO}"
  echo "Setting up initial load for '${REPLICATE_TO}'..."
  ./bin/symadmin --engine "${GROUP_ID}" reload-node "${REPLICATE_TO}"
fi

# Start SymmetricDS
echo "Starting SymmtricDS..."
exec "./bin/sym"
