#! /bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}/symmetric-server"

# Environment variables
source "${SCRIPT_DIR}/env.cfg"

function mandatoryCheck () {
  if [[ -z "${1}" ]]; then
    echo "You must set ${2}" && exit 1;
  fi
}

# Log4J logging level standard SymmetricDS channels
SYMDS_LOG_LEVEL="${LOG_LEVEL:-ALL}"
# Log4J logging level for channels that may contain data
DATA_LOG_LEVEL="${DATA_LOG_LEVEL:-ALL}"
# Log4J logging level for all other channels
LOG_LEVEL="${LOG_LEVEL:-ALL}"

mandatoryCheck "${SYNC_URL}" "SYNC_URL"
mandatoryCheck "${DB_NAME}" "DB_NAME"
mandatoryCheck "${DB_USER}" "DB_USER"
mandatoryCheck "${DB_PASS}" "DB_PASS"

# these must be set if it's in source mode
if [[ -z "${REGISTRATION_URL}" ]]; then
  mandatoryCheck "${REPLICATE_TO}" "REPLICATE_TO"
  mandatoryCheck "${REPLICATE_TABLES}" "REPLICATE_TABLES"
fi


# exit early if only username or password is set but not both!
if [[ -n "${USERNAME}" ]]; then
   mandatoryCheck "${PASSWORD}" "PASSWORD"
fi
if [[ -n "$PASSWORD" ]]; then
   mandatoryCheck "${USERNAME}" "USERNAME"
fi

# Build other variables
HTTP_ENABLE="false"
HTTP_PORT="31415"
HTTPS_ENABLE="false"
HTTPS_PORT="31417"

# Keystore password
p="changeit"

cd security

if [ "${HTTPS}" == "FALSE" ]; then
  HTTP_ENABLE="true"
  HTTP_PORT="${LISTEN_PORT:-${HTTP_PORT}}"
else
  LISTEN_PORT="${LISTEN_PORT:-31417}"
  HTTPS_ENABLE="true"
  HTTPS_PORT="${LISTEN_PORT:-${HTTPS_PORT}}"

  mkdir -p .keystore
  rm keystore

  if [[ -n "${HTTPS_CRT}" ]]; then
    # Use provided key-pair
    mandatoryCheck "${HTTPS_KEY}" "HTTPS_KEY"

    echo -n "${HTTPS_CRT}" | base64 -d > .keystore/crt
    echo -n "${HTTPS_KEY}" | base64 -d > .keystore/key
  else
    # No key-pair provided so auto-generate one
    openssl genrsa -out .keystore/key 4096
    openssl req \
            -new \
            -x509 \
            -sha256 \
            -days 365 \
            -key .keystore/key \
            -subj "/CN=${HOSTNAME}" \
            -out .keystore/crt
  fi

  openssl pkcs12 -export -out .keystore/keystore.p12 -inkey .keystore/key -in .keystore/crt -name "sym" -passout "pass:${p}"
  keytool -importkeystore -noprompt \
          -srckeystore .keystore/keystore.p12 -srcstoretype PKCS12 -srcstorepass "${p}" -srcalias "sym" \
          -destkeystore keystore -deststoretype jceks -deststorepass "${p}" -destalias "sym"

  rm -rf .keystore
fi

if [[ -n "${HTTPS_CA_BUNDLE}" ]]; then
    rm cacerts
    mkdir -p .cacerts
    echo -n "${HTTPS_CA_BUNDLE}" | base64 -d > .cacerts/https.pem
    keytool -importcert -noprompt \
            -keystore cacerts -storepass "${p}" -storetype jks \
            -file .cacerts/https.pem
fi

if [ -n "${DB_CA}" ]; then
    mkdir -p .cacerts
    echo -n "${DB_CA}" | base64 -d > .cacerts/db.pem
    keytool -importcert -noprompt \
            -keystore cacerts -storepass "${p}" -storetype jks \
            -file .cacerts/db.pem
fi

cd ..

JDBC_URL_PARAMS=""

case "${DB_TYPE}" in
  "mysql")
    DB_PORT="${DB_PORT:-3306}"
    DB_CMD="mysql -h \"${DB_HOST}\" -P \"${DB_POST}\" -u \"${DB_USER}\" -p\"${DB_PASS}\" \"${DB_NAME}\""
    JDBC_DRIVER="com.mysql.jdbc.Driver"
    if [ "${DB_SSL}" != "FALSE" ]; then
        echo "Warning: SSL support MySQL has not been tested."
        if [ -n "${DB_CA}" ]; then
            JDBC_URL_PARAMS="?useSSL=true&requireSSL=true&clientCertificateKeyStoreUrl=${PWD}/security/cacerts&clientCertificateKeyStorePassword=${p}"
        else
            JDBC_URL_PARAMS="?useSSL=true&requireSSL=true&verifyServerCertificate=false"
        fi
    else
        JDBC_URL_PARAMS="?allowPublicKeyRetrieval=true&useSSL=false"
    fi
    JDBC_URL="jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}${JDBC_URL_PARAMS}"
    echo "Warning: There appears to be a bug in MySQL support."
    ;;
  "oracle")
    DB_PORT="${DB_PORT:-1521}"
    DB_CMD="sqlplus64 \"${DB_USER}/${DB_PASS}@//${DB_HOST}:${DB_PORT}/${DB_NAME}\""
    JDBC_DRIVER="oracle.jdbc.driver.OracleDriver"
    if [ "${DB_SSL}" != "FALSE" ]; then
        echo "Warning: SSL is not yet supported for Oracle."
    fi
    JDBC_URL="jdbc:oracle:thin:@${DB_HOST}:${DB_PORT}:${DB_NAME}"
    echo "Warning: Some docker images of Oracle will listen to their port before they are ready to accept connections which will break this image."
    ;;
  "postgres")
    DB_PORT="${DB_PORT:-5432}"
    DB_CMD="PGPASSWORD=\"${DB_PASS}\" psql -w -h \"${DB_HOST}\" -p \"${DB_POST}\" \"${DB_NAME}\" \"${DB_USER}\""
    JDBC_DRIVER="org.postgresql.Driver"
    if [ "${DB_SSL}" != "FALSE" ]; then
        if [ -n "${DB_CA}" ]; then
            JDBC_URL_PARAMS="?ssl=true&sslrootcert=${PWD}/security/.cacerts/db.pem&sslmode=verify-full"
        else
            JDBC_URL_PARAMS="?ssl=true&sslfactory=org.postgresql.ssl.NonValidatingFactory"
        fi
    else
        JDBC_URL_PARAMS="?ssl=false"
    fi
    JDBC_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}${JDBC_URL_PARAMS}"
    ;;
esac

# Configure according to environment variables
cat << EOL > "./conf/symmetric-server.properties"
rest.api.enable=true
host.bind.name=${LISTEN_HOST}
http.enable=${HTTP_ENABLE}
http.port=${HTTP_PORT}
https.enable=${HTTPS_ENABLE}
https.port=${HTTPS_PORT}
https.allow.self.signed.certs=false
jmx.http.enable=false
jmx.http.port=31416
server.access.log.enabled=true
server.access.log.file=logs/access.log
EOL

cat << EOL > "./conf/log4j.xml"
<?xml version="1.0" encoding="UTF-8"?>
<!--

    Licensed to JumpMind Inc under one or more contributor
    license agreements.  See the NOTICE file distributed
    with this work for additional information regarding
    copyright ownership.  JumpMind Inc licenses this file
    to you under the GNU General Public License, version 3.0 (GPLv3)
    (the "License"); you may not use this file except in compliance
    with the License.

    You should have received a copy of the GNU General Public License,
    version 3.0 (GPLv3) along with this library; if not, see
    <http://www.gnu.org/licenses/>.

    Unless required by applicable law or agreed to in writing,
    software distributed under the License is distributed on an
    "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
    KIND, either express or implied.  See the License for the
    specific language governing permissions and limitations
    under the License.

-->
<!DOCTYPE log4j:configuration SYSTEM "log4j.dtd">

<log4j:configuration xmlns:log4j="http://jakarta.apache.org/log4j/" debug="false">

    <appender name="ROLLING" class="org.jumpmind.util.SymRollingFileAppender">
        <param name="File" value="\${log4j.sym.home}/logs/symmetric.log" />
        <param name="MaxFileSize" value="20MB" />
        <param name="MaxBackupIndex" value="3" />
        <param name="Append" value="true" />
        <layout class="org.jumpmind.symmetric.web.SymPatternLayout">
            <param name="ConversionPattern" value="%d %p [%X{engineName}] [%c{1}] [%t] %m%n" />
        </layout>
    </appender>

    <appender name="CONSOLE" class="org.apache.log4j.ConsoleAppender">
        <param name="Target" value="System.err" />
        <layout class="org.jumpmind.symmetric.web.SymPatternLayout">
            <param name="ConversionPattern" value="%d{ISO8601} %p: [%X{engineName}] - %c{1} - %m%n" />
        </layout>
    </appender>

    <appender name="BUFFERED" class="org.jumpmind.util.BufferedLogAppender"/>

    <!-- Uncomment to send errors over email.  (1/2) -->
    <!--
    <appender name="EMAIL" class="org.apache.log4j.net.SMTPAppender">
        <param name="SMTPHost" value="mymailhost" />
        <param name="SMTPUsername" value="" />
        <param name="SMTPPassword" value="" />
        <param name="From" value="user@nowhere" />
        <param name="To" value="user@nowhere" />
        <param name="Subject" value="Error from SymmetricDS" />
        <param name="BufferSize" value="10" />
        <param name="LocationInfo" value="true" />
        <layout class="org.apache.log4j.PatternLayout">
            <param name="ConversionPattern" value="%t %m%n"/>
        </layout>
        <filter class="org.apache.log4j.varia.LevelRangeFilter">
            <param name="LevelMin" value="error" />
            <param name="LevelMax" value="fatal" />
        </filter>
    </appender>
    -->

    <category name="org">
        <priority value="${LOG_LEVEL}" />
    </category>

    <category name="org.jumpmind">
        <priority value="${SYMDS_LOG_LEVEL}" />
    </category>

    <category name="com.mangofactory.swagger.filters.AnnotatedParameterFilter">
        <priority value="ERROR" />
    </category>

    <category name="oracle.jdbc">
        <priority value="${DATA_LOG_LEVEL}" />
    </category>
    <category name="org.mysql">
        <priority value="${DATA_LOG_LEVEL}" />
    </category>
    <category name="org.postgresql">
        <priority value="${DATA_LOG_LEVEL}" />
    </category>
    <category name="org.jumpmind.db">
        <priority value="${DATA_LOG_LEVEL}" />
    </category>
    <category name="org.jumpmind.db.sql">
        <priority value="${DATA_LOG_LEVEL}" />
    </category>
    <category name="org.jumpmind.db.platform">
        <priority value="${DATA_LOG_LEVEL}" />
    </category>
    <category name="org.jumpmind.symmetric.io.data">
        <priority value="${DATA_LOG_LEVEL}" />
    </category>
    <category name="org.jumpmind.symmetric.db">
        <priority value="${DATA_LOG_LEVEL}" />
    </category>
    <category name="org.jumpmind.symmetric.db.SqlScript">
        <priority value="${DATA_LOG_LEVEL}" />
    </category>

    <!-- Disable the not found override properties file warnings to avoid confusion -->
    <category name="org.jumpmind.symmetric.util.PropertiesFactoryBean">
        <priority value="ERROR" />
    </category>

    <category name="org.jumpmind.symmetric.service.impl.ParameterService">
        <priority value="ERROR" />
    </category>

    <category name="org.springframework">
        <priority value="ERROR" />
    </category>

    <category name="com.vaadin.server.DefaultDeploymentConfiguration">
        <priority value="ERROR" />
    </category>

    <category name="com.vaadin.event.ConnectorActionManager">
        <priority value="ERROR" />
    </category>

    <category name="com.vaadin.server.communication">
        <priority value="FATAL" />
    </category>

    <category name="org.atmosphere">
        <priority value="FATAL" />
    </category>

    <!-- Uncomment to see CSV protocol from sending batches -->
    <!--
    <category name="org.jumpmind.symmetric.io.data.writer.ProtocolDataWriter">
        <priority value="DEBUG"/>
    </category>
    -->

    <!-- Uncomment to see SQL statements from loading batches -->
    <!--
    <category name="org.jumpmind.symmetric.io.data.writer.DefaultDatabaseWriter">
        <priority value="DEBUG" />
    </category>
    -->

    <!-- Enable this to see debug messages in JMS publishing extensions -->
    <!--
    <category name="org.jumpmind.symmetric.integrate">
        <priority value="DEBUG" />
    </category>
    -->

    <!-- Enable this to see debug messages for why SymmetricDS tables are being altered -->
    <!--
    <category name="org.jumpmind.db.alter">
        <priority value="DEBUG" />
    </category>
    -->

    <!-- In order to see http headers enable this, and also edit logging.properties
    <category name="sun.net.www.protocol.http.HttpURLConnection">
        <priority value="ALL" />
    </category>
     -->

    <!-- Change the "CONSOLE" to "ROLLING" to log to a file instead -->
    <root>
        <priority value="${LOG_LEVEL}" />
        <appender-ref ref="CONSOLE" />
        <!--
        <appender-ref ref="ROLLING" />
        <appender-ref ref="BUFFERED" />
        -->
        <!-- Uncomment to send errors over email. (2/2) -->
        <!--
        <appender-ref ref="EMAIL" />
        -->
    </root>

</log4j:configuration>
EOL

cat << EOL > "./engines/${ENGINE_NAME}-${EXTERNAL_ID}.properties"
rest.api.enable=true
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

if [[ -n "${REPLICATE_TO}" ]]; then
  cat << EOL >> "./engines/${ENGINE_NAME}-${EXTERNAL_ID}.properties"
initial.load.create.first=true
EOL
fi

if [[ -n "${USERNAME}" && -n "${PASSWORD}" ]]; then
  # basic auth setup!!
  sed -i "s|</web-app>|<security-constraint><web-resource-collection><url-pattern>/*</url-pattern></web-resource-collection><auth-constraint><role-name>user</role-name></auth-constraint></security-constraint><login-config><auth-method>BASIC</auth-method><realm-name>default</realm-name></login-config></web-app>|" ./web/WEB-INF/web.xml

  echo -n "${USERNAME}: ${PASSWORD},user" >> ./web/WEB-INF/realm.properties

  echo -e "<Configure class=\"org.eclipse.jetty.webapp.WebAppContext\"> \n
<Get name=\"securityHandler\"> \n
<Set name=\"loginService\"> \n
<New class=\"org.eclipse.jetty.security.HashLoginService\"> \n
<Set name=\"name\">default</Set> \n
<Set name=\"config\"><SystemProperty name=\"user.dir\" default=\".\"/>/web/WEB-INF/realm.properties</Set> \n
</New> \n
</Set> \n
</Get> \n
</Configure>" >> ./web/WEB-INF/jetty-web.xml

  cat << EOL >> "./engines/${ENGINE_NAME}-${EXTERNAL_ID}.properties"
http.basic.auth.username=${USERNAME}
http.basic.auth.password=${PASSWORD}
EOL
  #end of basic auth setup
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

if [[ -n "${REPLICATE_TO}" ]]; then
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
EOL

  for REPLICATE_TABLE in $REPLICATE_TABLES; do
    if [[ $REPLICATE_TABLE == *"|"* ]]; then
      echo 'Found cols in table config'
      REPLICATE_COLS=${REPLICATE_TABLE#*|}
      REPLICATE_TABLE=${REPLICATE_TABLE%|*}
      echo "REPLICATE_TABLE=$REPLICATE_TABLE and REPLICATE_COLS=$REPLICATE_COLS"
    fi

    echo "Adding config for $REPLICATE_TABLE in ${DB_TYPE}..."
    cat << EOL >> "init.sql"
insert into sym_channel
(channel_id, processing_order, max_batch_size, max_batch_to_send, extract_period_millis, batch_algorithm, enabled)
      values ('${REPLICATE_TABLE}', 10, 1000, 10, 0, 'default', 1);

insert into sym_trigger
(trigger_id, source_table_name, channel_id, last_update_time, create_time, included_column_names)
      values ('${REPLICATE_TABLE}', '${REPLICATE_TABLE}', '${REPLICATE_TABLE}', current_timestamp, current_timestamp, '${REPLICATE_COLS}');

insert into sym_trigger_router
(trigger_id, router_id, initial_load_order, create_time, last_update_time)
      values ('${REPLICATE_TABLE}', '${GROUP_ID}-2-${REPLICATE_TO}', 1, current_timestamp, current_timestamp);
EOL
  done

  ./bin/symadmin --engine "${GROUP_ID}" create-sym-tables
  ./bin/dbimport --engine "${GROUP_ID}" "init.sql"
  echo "Opening registration for '${REPLICATE_TO}'..."
  ./bin/symadmin --engine "${GROUP_ID}" open-registration "${REPLICATE_TO}" "${REPLICATE_TO}"
  echo "Setting up initial load for '${REPLICATE_TO}'..."
  ./bin/symadmin --engine "${GROUP_ID}" reload-node "${REPLICATE_TO}"
fi

# Start SymmetricDS
echo "Starting SymmetricDS..."
exec "./bin/sym"
