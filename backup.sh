#!/usr/bin/env zsh

DIR=backup/$(date +%Y%m%d_%H%M%S)

mkdir -p $DIR

docker-compose stop
mkdir -p backup
docker run --rm --name temp_backup --volumes-from cvat_db -v $(pwd)/$DIR:/backup ubuntu tar -cjvf /backup/cvat_db.tar.bz2 /var/lib/postgresql/data
docker run --rm --name temp_backup --volumes-from cvat_elasticsearch -v $(pwd)/$DIR:/backup ubuntu tar -cjvf /backup/cvat_events.tar.bz2 /usr/share/elasticsearch/data

docker-compose \
-f docker-compose.yml \
-f docker-compose.dev.yml \
-f docker-compose.override.yml \
-f components/analytics/docker-compose.analytics.yml \
up -d --build

~/mc cp -r $DIR minio/cvat-backup

find -type d -path "./backup/*" -ctime +30 -exec rm -rf {} \;
~/mc rm --recursive --force --older-than 60d minio/cvat-backup

