# Server init setup

[Default server setup](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-16-04#step-five-%E2%80%94-disable-password-authentication-(recommended))

# CVAT setup

## Install docker

```bash
sudo apt-get update
sudo apt-get --no-install-recommends install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"
sudo apt-get update
sudo apt-get --no-install-recommends install -y docker-ce docker-ce-cli containerd.io
```

## Perform post-installation steps to run docker without root permissions

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
```

### Rebooting...

## Install docker-compose

```bash
sudo apt-get --no-install-recommends install -y python3-pip python3-setuptools
sudo python3 -m pip install setuptools docker-compose
```

## Clone CVAT source code from the GitHub repository.

```bash
sudo apt-get --no-install-recommends install -y git
git clone git@github.com:EvoCargo/cvat.git
cd cvat
git checkout evo/master
```

## Setup environments variables.

```bash
export CVAT_HOST=cvat.evocargo.com
export ACME_EMAIL=your.email@evocargo.com
```

## Run docker containers.

```bash
docker-compose \
  -f docker-compose.yml \
  -f docker-compose.dev.yml \
  -f docker-compose.https.yml \
  -f docker-compose.override.yml \
  -f components/analytics/docker-compose.analytics.yml \
  up -d --build
```

## Create superuser

```bash
docker exec -it cvat bash -ic 'python3 ~/manage.py createsuperuser'
```

# Backup data

Run script

```bash
./backup.sh
```

# Restore data from backup

Create dir `backup` inside `cvat` directory and put to it 3 backup files:
- `cvat_data.tar.bz2`
- `cvat_events.tar.bz2`
- `cvat_db.tar.bz2`

Then run command

```bash
docker-compose stop
cd backup
docker run --rm --name temp_backup --volumes-from cvat_db -v $(pwd):/backup ubuntu bash -c "cd /var/lib/postgresql/data && tar -xvf /backup/cvat_db.tar.bz2 --strip 4"
docker run --rm --name temp_backup --volumes-from cvat -v $(pwd):/backup ubuntu bash -c "cd /home/django/data && tar -xvf /backup/cvat_data.tar.bz2 --strip 3"
docker run --rm --name temp_backup --volumes-from cvat_elasticsearch -v $(pwd):/backup ubuntu bash -c "cd /usr/share/elasticsearch/data && tar -xvf /backup/cvat_events.tar.bz2 --strip 4"
cd ..
docker-compose \
  -f docker-compose.yml \
  -f docker-compose.dev.yml \
  -f docker-compose.https.yml \
  -f docker-compose.override.yml \
  -f components/analytics/docker-compose.analytics.yml \
  up -d --build
```
