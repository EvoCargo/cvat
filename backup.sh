#!/usr/bin/env zsh

# Define directory with current datetime
DIR=$HOME/backup/$(date +%Y%m%d_%H%M%S)

# Create this dir if not exist
mkdir -p $DIR


# Stop all containers and get backup data from posgres db with annotation data and kibana data
docker-compose stop
mkdir -p backup

docker run --rm --name temp_backup --volumes-from cvat_db -v $DIR:/backup ubuntu tar -cjvf /backup/cvat_db.tar.bz2 /var/lib/postgresql/data

docker run --rm --name temp_backup --volumes-from cvat -v $DIR:/backup ubuntu tar -cjvf /backup/cvat_data.tar.bz2 /home/django/data

docker run --rm --name temp_backup --volumes-from cvat_elasticsearch -v $DIR:/backup ubuntu tar -cjvf /backup/cvat_events.tar.bz2 /usr/share/elasticsearch/data


# Run all stoped containers
docker-compose \
-f docker-compose.yml \
-f docker-compose.dev.yml \
-f docker-compose.override.yml \
-f components/analytics/docker-compose.analytics.yml \
up -d --build

# Copy created dir with backup data to min.oi storage
~/mc cp -r $DIR minio/cvat-backup

# Delete all backups older than 5 days from this server
find ~/backup/* -type d -ctime +5 -exec rm -rf {} \;

# Delete all backups older than 30 days from min.io storage
~/mc rm --recursive --force --older-than 30d minio/cvat-backup

