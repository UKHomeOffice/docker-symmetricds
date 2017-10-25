FROM quay.io/ukhomeofficedigital/centos-base:latest

RUN yum install -y -q java-1.8.0-openjdk nmap-ncat openssl unzip \
 && yum update -y -q \
 && yum clean all \
 && rpm --rebuilddb \
 && useradd -rUm symds -d /app/ \
 && chown -R symds:symds /app/

USER symds
WORKDIR /app

ENV SYMMETRICDS_VERSION 3.8.30

RUN MINOR=`echo "${SYMMETRICDS_VERSION}" | sed 's/\.[^.]*$//'` \
 && curl -L -o 'symmetricds.zip' "https://downloads.sourceforge.net/project/symmetricds/symmetricds/symmetricds-${MINOR}/symmetric-server-${SYMMETRICDS_VERSION}.zip" \
 && unzip 'symmetricds.zip' \
 && rm 'symmetricds.zip' \
 && ln -s "symmetric-server-${SYMMETRICDS_VERSION}/" 'symmetric-server'

COPY entrypoint.sh /app/

USER root
RUN yum update -y -q \
 && yum clean all \
 && rpm --rebuilddb

USER symds
CMD ["./entrypoint.sh"]
