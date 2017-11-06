#! /bin/env bash

cat << END-OF-LINE
SOURCE_CRT=`cat .docker-compose/source.crt | base64 | tr -d '\n'`
SOURCE_KEY=`cat .docker-compose/source.key | base64 | tr -d '\n'`
TARGET_CRT=`cat .docker-compose/target.crt | base64 | tr -d '\n'`
TARGET_KEY=`cat .docker-compose/target.key | base64 | tr -d '\n'`
END-OF-LINE
