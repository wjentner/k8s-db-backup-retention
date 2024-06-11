FROM alpine:3.20

ENV BACKUP_RETENTION_SECONDS=43200
ENV BACKUP_DB_USER=root
ENV BACKUP_DB_PASSWORD=setMe!
ENV BACKUP_DIR=/backups
ENV BACKUP_FILE_PREFIX=db-backup
ENV BACKUP_K8S_DB_NAMESPACE=default
ENV BACKUP_K8S_DB_POD=mariadb-0
ENV BACKUP_EXEC=mysqldump
ENV BACKUP_DATABASES=--all-databases

RUN apk add --update bash kubectl gzip

ADD ./run_backup.sh /run_backup.sh

RUN chmod +x run_backup.sh

CMD /run_backup.sh
