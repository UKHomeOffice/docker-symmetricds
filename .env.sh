#! /bin/env bash

cat << END-OF-LINE
SOURCE_CRT=`cat .docker-compose/source.crt | base64 -w0`
SOURCE_KEY=`cat .docker-compose/source.key | base64 -w0`
TARGET_CRT=`cat .docker-compose/target.crt | base64 -w0`
TARGET_KEY=`cat .docker-compose/target.key | base64 -w0`
END-OF-LINE
