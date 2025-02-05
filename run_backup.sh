#!/bin/bash

echo "$(date -Iseconds): Begin backup"

DATE=$(date -Iseconds)
MIN="${BACKUP_RETENTION_MINUTES}"

DB="${BACKUP_FILE_PREFIX}"
FILE="${BACKUP_DIR}/${DB}-${DATE}.sql.gz"

# this might error if there are no files in the directory
LASTFILE=$(ls -Art $BACKUP_DIR/* | tail -n 1)

# starting from here let script fail if there are errors
set -e

if [ "${BACKUP_EXEC}" == "pg_dump" ] || [ "${BACKUP_EXEC}" == "pg_dumpall" ]
then
  kubectl -n "${BACKUP_K8S_DB_NAMESPACE}" exec "${BACKUP_K8S_DB_POD}" -- sh -c 'echo "*:*:*:'${BACKUP_DB_USER}':'${BACKUP_DB_PASSWORD}'" > /tmp/.pgpass && chmod 0600 /tmp/.pgpass'
  if [ "${BACKUP_EXEC}" == "pg_dump" ]
  then
    kubectl -n "${BACKUP_K8S_DB_NAMESPACE}" exec "${BACKUP_K8S_DB_POD}" -- sh -c 'PGPASSFILE="/tmp/.pgpass" "'${BACKUP_EXEC}'" -U"'${BACKUP_DB_USER}'" -d"'${BACKUP_DB_NAME}'"' | gzip -9 -c > $FILE
  else
    kubectl -n "${BACKUP_K8S_DB_NAMESPACE}" exec "${BACKUP_K8S_DB_POD}" -- sh -c 'PGPASSFILE="/tmp/.pgpass" "'${BACKUP_EXEC}'" -U"'${BACKUP_DB_USER}'"' | gzip -9 -c > $FILE
  fi
  kubectl -n "${BACKUP_K8S_DB_NAMESPACE}" exec "${BACKUP_K8S_DB_POD}" -- rm /tmp/.pgpass
elif [ "${BACKUP_EXEC}" == "mysqldump" ] || [ "${BACKUP_EXEC}" == "mariadb-dump" ]
then
  kubectl -n "${BACKUP_K8S_DB_NAMESPACE}" exec "${BACKUP_K8S_DB_POD}" -- "${BACKUP_EXEC}" -u"${BACKUP_DB_USER}" -p"${BACKUP_DB_PASSWORD}" "${BACKUP_DATABASES}" | gzip -9 -c > $FILE
else
  echo "$(date -Iseconds): Unknown backup command ("${BACKUP_EXEC}")"
  exit 1
fi

chmod 0600 $FILE
echo "$(date -Iseconds): Backup written to file ${FILE}"

set +e
zcmp -s $FILE $LASTFILE >/dev/null 2>&1
if [ $? -eq 0 ] #the new file is equal to the old file
then
  echo "$(date -Iseconds): New backup identical to last backup - remove last backup ${LASTFILE}"
  rm -v "$LASTFILE"
else #the new file is not equal to the old one
  #we delete the old files
  echo "$(date -Iseconds): Remove outdated backups"
  find "${BACKUP_DIR}" -name "$DB*.sql*gz" -type f -mmin +$MIN -print -delete
fi

echo "$(date -Iseconds): Backup complete"
exit 0
