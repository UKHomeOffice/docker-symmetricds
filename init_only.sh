#!/usr/bin/env bash

set -e

echo "Waiting for Oracle XE configure to complete..."
while [[ $(ps ax | grep '/etc/init.d/oracle-xe configure' | sed '/grep/d') ]]; do
    echo "..."
    sleep 5
done

if [[ ! -f /u01/app/LEV_API/import_done ]]; then
    echo "Doing initial LEV import..."
    # TODO: Script not finished - see script!
    su - oracle -c "/u01/app/LEV_API/import_lev_data.sh"
    touch /u01/app/LEV_API/import_done
else
    echo "Import done, skipping import"
fi

if [[ ! -f /opt/ords.3.0.0/done ]]; then
    echo "Setting up ORDS..."
    echo "=================="
    su - oracle -c "/opt/ords.3.0.0/setup_ords.sh -h localhost"
    touch /opt/ords.3.0.0/done
fi

if [[ ! -f /u01/app/LEV_API/done ]]; then
    echo "Importing LEV Data..."
    echo "====================="
    su - oracle -c "/u01/app/LEV_API/lev_ords_view.sh"
    touch /u01/app/LEV_API/done
fi
