FROM almalinux:latest

RUN dnf install -y -q epel-release \
 && dnf install -y -q java-1.8.0-openjdk nmap-ncat openssl unzip jq \
 && dnf update -y -q \
 && dnf clean all \
 && useradd -rUm symds -u 10007 -d /app/ \
 && chown -R symds:symds /app/

USER 10007
WORKDIR /app

ENV SYMMETRICDS_VERSION 3.13.3

RUN MINOR=`echo "${SYMMETRICDS_VERSION}" | sed 's/\.[^.]*$//'` \
 && curl -L -o 'symmetricds.zip' "https://downloads.sourceforge.net/project/symmetricds/symmetricds/symmetricds-${MINOR}/symmetric-server-${SYMMETRICDS_VERSION}.zip" \
 && unzip 'symmetricds.zip' \
 && rm 'symmetricds.zip' \
 && ln -s "symmetric-server-${SYMMETRICDS_VERSION}/" 'symmetric-server'

RUN rm symmetric-server/lib/mysql-connector-java-*.jar \
 && curl -L -o 'symmetric-server/lib/mysql-connector-java-8.0.20.jar' "https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.20/mysql-connector-java-8.0.20.jar"

COPY entrypoint.sh env.cfg liveness.sh readiness.sh /app/

USER root
RUN dnf update -y -q \
 && dnf clean all

COPY sym_service.conf /app/symmetric-server/conf

USER 10007
CMD ["./entrypoint.sh"]
