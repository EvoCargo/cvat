# Server init setup

[Default server setup](https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-16-04#step-five-%E2%80%94-disable-password-authentication-(recommended))

# CVAT setup

## 1. Install docker

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

## 2. Perform post-installation steps to run docker without root permissions

sudo groupadd docker
sudo usermod -aG docker $USER

### Rebooting...

## 3. Install docker-compose

sudo apt-get --no-install-recommends install -y python3-pip python3-setuptools
sudo python3 -m pip install setuptools docker-compose

## 4. Clone CVAT source code from the GitHub repository.

sudo apt-get --no-install-recommends install -y git
git clone git@github.com:EvoCargo/cvat.git
cd cvat
git checkout evocargo


## 5. Create docker-compose.override.yml 


NUCLIO_VERSION=1.6.1
cat <<EOT >> docker-compose.override.yml
version: '3.3'
 
services:
  cvat_proxy:
    environment:
      CVAT_HOST: 'cvat.evocargo.com'
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./letsencrypt-webroot:/var/tmp/letsencrypt-webroot
      - /etc/ssl/private:/etc/ssl/private
 
  serverless:
    container_name: nuclio
    image: quay.io/nuclio/dashboard:1.6.1-amd64
 
  cvat:
    environment:
      ALLOWED_HOSTS: '*'
      CVAT_SHARE_URL: 'Mounted from /home/dkorshunov/cvat/share host directory'
    volumes:
      - cvat_share:/home/django/share:ro
    build:
      context: .
      args:
        http_proxy:
        https_proxy:
        no_proxy: nuclio,${no_proxy}
        socks_proxy:
        USER: 'django'
        DJANGO_CONFIGURATION: 'production'
        TZ: 'Etc/UTC'
        CLAM_AV: 'no'  vim 
    
volumes:
  cvat_share:
    driver_opts:
      type: none
      device: /home/evocargo/cvat/share
      o: bind
 
EOT


## 6. Run docker containers.

docker-compose \
  -f docker-compose.yml \
  -f docker-compose.dev.yml \
  -f docker-compose.override.yml \
  -f components/analytics/docker-compose.analytics.yml \
  -f components/serverless/docker-compose.serverless.yml \
  up -d --build


## 7. Create superuser

docker exec -it cvat bash -ic 'python3 ~/manage.py createsuperuser'

## 8. Deploy secure CVAT instance with HTTPS

[Follow the guide](https://github.com/openvinotoolkit/cvat/blob/develop/cvat/apps/documentation/installation.md#deploy-secure-cvat-instance-with-https)


## 9. To install nuctl tool to build and deploy serverless functions.

```
NUCLIO_VERSION=1.6.1
wget https://github.com/nuclio/nuclio/releases/download/$NUCLIO_VERSION/nuctl-$NUCLIO_VERSION-linux-amd64
sudo chmod +x nuctl-$NUCLIO_VERSION-linux-amd64
sudo ln -sf $(pwd)/nuctl-$NUCLIO_VERSION-linux-amd64 /usr/local/bin/nuctl
nuctl create project cvat

./serverless/deploy_cpu.sh
./serverless/deploy_gpu.sh
```


# Backup data

docker-compose stop

mkdir backup
docker run --rm --name temp_backup --volumes-from cvat_db -v $(pwd)/backup:/backup ubuntu tar -cjvf /backup/cvat_db.tar.bz2 /var/lib/postgresql/data
docker run --rm --name temp_backup --volumes-from cvat -v $(pwd)/backup:/backup ubuntu tar -cjvf /backup/cvat_data.tar.bz2 /home/django/data
docker run --rm --name temp_backup --volumes-from cvat_elasticsearch -v $(pwd)/backup:/backup ubuntu tar -cjvf /backup/cvat_events.tar.bz2 /usr/share/elasticsearch/data


docker-compose \
  -f docker-compose.yml \
  -f docker-compose.dev.yml \
  -f docker-compose.override.yml \
  -f components/analytics/docker-compose.analytics.yml \
  -f components/serverless/docker-compose.serverless.yml \
  up -d --build


#Restor data

docker-compose stop

cd backup

docker run --rm --name temp_backup --volumes-from cvat_db -v $(pwd):/backup ubuntu bash -c "cd /var/lib/postgresql/data && tar -xvf /backup/cvat_db.tar.bz2 --strip 4"
docker run --rm --name temp_backup --volumes-from cvat -v $(pwd):/backup ubuntu bash -c "cd /home/django/data && tar -xvf /backup/cvat_data.tar.bz2 --strip 3"
docker run --rm --name temp_backup --volumes-from cvat_elasticsearch -v $(pwd):/backup ubuntu bash -c "cd /usr/share/elasticsearch/data && tar -xvf /backup/cvat_events.tar.bz2 --strip 4"

cd ..

docker-compose \
  -f docker-compose.yml \
  -f docker-compose.dev.yml \
  -f docker-compose.override.yml \
  -f components/analytics/docker-compose.analytics.yml \
  -f components/serverless/docker-compose.serverless.yml \
  up -d --build


