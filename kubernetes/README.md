# Setup K3s Kubernetes Cluster

# Configure Traefik with extra values

The Traefik ingress controller is deployed along with K3s. To modify the
default values,

```bash
# k3s still uses traefik V2
helm upgrade traefik traefik/traefik \
  -n kube-system -f traefik/traefik-values.yaml \
  --version 22.1.0
```

# Configure Cert Manager for automating SSL certificate handling

Cert manager handles SSL certificate creation and renewal from Let's Encrypt.

```bash
helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.15.3 \
  --set crds.enabled=true \
  --set prometheus.enabled=false \
  --set webhook.timeoutSeconds=4 \
```

Next, deploy the certificate Issuer. Issuers, and ClusterIssuers,
are Kubernetes resources that represent certificate authorities (CAs) that are
able to generate signed certificates by honoring certificate signing requests.
All cert-manager certificates require a referenced issuer that is in a ready
condition to attempt to honor the request.
[Ref](https://cert-manager.io/docs/concepts/issuer/).

The template for ClusterIssuer is in the cert-manager directory. A single
wildcard-cert will be created and used for all ingress subdomains. Create a new
certificate and cert in cert directory and copy the secret manually to all the
namespaces.

First add the DNS servers to the coreDNS config:

```bash
export KUBE_EDITOR=nvim
# Change the forward section with . 1.1.1.1 1.0.0.1
kubectl -n kube-system edit configmap coredns
```

Next, deploy the ClusterIssuer, WildcardCert, and secrets using helm

```bash
source .env
helm install cert-handler cert-manager-helm-chart \
  --atomic --set secret.apiToken=$CLOUDFLARE_TOKEN \
  --set clusterIssuer.email=$EMAIL \
  --set wildcardCert.dnsNames[0]=$DNSNAME

# Copy the wildcard certificate to other namespaces
kubectl get secret wildcard-cert-secret --namespace=cert-manager -o yaml \
  | sed 's/namespace: cert-manager/namespace: <namespace>/' | kubectl apply -f -
```

If for some reason certificate secret `wildcard-cert-secret` is not generated,
the issue can be related to cloudflare API token is wrong, the token secret is
missing, the Issuer or ClusterIssuer is not ready etc.

Here are some troubleshoot commands to test:

```bash
kubectl get clusterissuer
kubectl describe clusterissuer
kubectl get certificate -n cert-manager
kubectl get certificateRequest -n cert-manager
kubectl describe challenges -n cert-manager
kubectl describe orders -n cert-manager
```

Alternatively, it is possible to generate service specific certs
in desired namespaces by deploying the Certificate resource in the namespace.

# Deploy Private Docker Registry

Create a new namespace called docker-registry and deploy the private
docker-registry.

First create docker credentials with htpasswd:

```bash
htpasswd -cB registry-passwords USERNAME

kubectl create namespace docker-registry
kubectl create secret generic registry-credentials \
  --from-file=.secrets/registry-passwords \
  -n docker-registry
```

Next, deploy the docker registry with helm chart:

```bash
source .env
helm install registry docker-registry-helm-chart/ \
  --set host=$DOCKER_REGISTRY_HOST \
  --set ingress.tls.host=$REGISTRY_HOST \
  --atomic
```

# Deploy Portfolio Website from Private Docker Registry

First, create the namespace and create a secret to access the private docker
registry.

```bash
kubectl create namespace my-portfolio

source .env
kubectl create secret docker-registry my-registry-secret \
  --docker-server="$DOCKER_REGISTRY_HOST" \
  --docker-username="$DOCKER_USER" \
  --docker-password="$DOCKER_PASSWORD" \
  -n my-portfolio

# use envsubst to substitute the environment variables in the manifest
envsubst < my-portfolio/portfolioManifest.yaml | \
  kubectl apply -n my-portfolio -f -
```

# Expose External Services via Traefik Ingress Controller

External services hosted outside the kubernetes cluster can be exposed using
the kubernetes traefik reverse proxy.

A nginx http server is deployed as a proxy that listens on port 80
and redirects requests to the proxmox local IP address. The server has an
associated clusterIP service which is exposed via ingress. The nginx proxy can
be configured to listen to other ports and forward traffic to other external
services running locally or remotely.

```bash
source .env
kubectl create namespace external-services
envsubst '${PROXMOX_IP} ${PROXMOX_HOST}' < external-service/proxmox.yaml | \
  kubectl apply -n external-services -f -
```

# Create Shared NFS Storage for Plex and Jellyfin

A 1TB NVME SSD is mounted to one of the original homelab VMs. This serves as an
NFS mount for all k3s nodes to use as shared storage for plex and jellyfin
containers.

## On the host VM:

```bash
sudo apt update
sudo apt install nfs-kernel-server
sudo chown nobody:nogroup /media/flexdrive

# Configure mount on /etc/fstab to persist across reboot
sudo vim /etc/fstab
# Add the following line. Change the filsystem if other than ntfs
# /dev/sdb2    /media/flexdrive    ntfs    defaults    0    2

# Configure NFS exports by editing the NFS exports file
sudo vim /etc/exports
# Add the following line to the file
# /media/flexdrive 192.168.1.113/24(rw,sync,no_subtree_check,no_root_squash)

# Apply the exports config
sudo exportfs -ra

# Start and enable NFS Server
sudo systemctl start nfs-kernel-server
sudo systemctl enable nfs-kernel-server
```

## On all the K3s VMs:

```
sudo apt install nfs-common
sudo mkdir /mnt/media
sudo mount 192.168.1.113:/media/flexdrive /mnt/media
# And test if the contents are visible
# After that unmount with the following command as mounting will be taken care
# by k8s
sudo umount /mnt/media
```

# Deploy Jellyfin Container in K3s

Jellyfin is a media server that can be used to organize, play, and stream
audio and video files. The Jellyfin container is deployed in the k3s cluster
using the NFS shared storage for media files. Due to segregated nature of the
media manifest files, it has not been helm charted.

```bash
source .env
kubectl create namespace media
kubectl get secret wildcard-cert-secret --namespace=cert-manager -o yaml \
  | sed 's/namespace: cert-manager/namespace: media/' | kubectl apply -f -

# Create a new storageclass called manual to not use longhorn storageclass
kubectl apply -f media/storageclass-nfs.yaml

# Create NFS PV and PVC
envsubst < media/pv.yaml | kubectl apply -n media -f -
kubectl apply -f media/pvc.yaml -n media

# Deploy Jellyfin
envsubst < media/jellyfin-deploy.yaml | kubectl apply -n media -f -
```

## Enable LDAP Authentication

In order to enable LDAP authentication for Jellyfin, the LDAP
plugin must be installed. The LDAP plugin is not included in the
Jellyfin helm chart. The plugin must be installed manually by
from the GUI.

1. Go to the Jellyfin web UI and login as admin.
2. Go to the Plugins section and click on the "Catalog" tab.
3. Search for the "LDAP" plugin and click on the "Install" button.
4. After the plugin is installed, go to the "Dashboard" section and click on
   the "LDAP" tab.
5. Configure the LDAP settings as follows:
   - LDAP Server:
     - Host: 192.168.1.144
     - Port: 3890
     - LDAP Bind User: UID=admin,OU=people,DC=homelab,DC=local
     - Bind Password:
     - LDAP Base DN for searches: DC=homelab,DC=local
     - LDAP Search Filter: (memberOf=CN=jellyfin_users,OU=groups,DC=homelab,DC=local)
     - LDAP Search Attribute: uid, cn, mail, displayName
     - LDAP Uid Attribute: uid
     - LDAP Username Attribute: CN
     - LDAP Password Attribute: userPassword
     - LDAP Admin Bind DN: dc=homelab,dc=local
     - LDAP Admin Filter: (memberOf=CN=jellyfin_users,OU=groups,DC=homelab,DC=local)

## Transfer media files from one PVC to another (Optional)

To transfer media files from one PVC to another, create a temporary pod to copy
files from one PVC to another. The following command will create a temporary
pod in the media namespace to copy files from one PVC to another.

```bash
# Create a temporary pod to copy files from one PVC to another
k apply -f temp-deploy.yaml -n media
# Copy files from one PVC to another
kubectl exec -it temp-pod -n media -- bash
cp -r /mnt/source/* /mnt/destination/
```

# Create Storage Solution

Longhorn is a distributed block storage solution for Kubernetes that is built
using containers. It provides a simple and efficient way to manage persistent
volumes. Longhorn is deployed in the k3s cluster to provide storage for the
containers. For security reasons, the longhorn UI is not exposed outside the
network. It is accessible locally via port-forwarding or loadbalancer.

In order to use Longhorn, the storage disk must be formatted and mounted on
each VM. The following commands format the disk and mount it on /mnt/longhorn
directory. For deployment, the longhorn helm chart is used to install longhorn
in the longhorn-system namespace.

```bash
# On each VM
sudo mkfs.ext4 /dev/sda4
sudo mkdir /mnt/longhorn
sudo mount /dev/sda4 /mnt/longhorn

# Add entry to /etc/fstab to persist across reboot
echo "/dev/sda4 /mnt/longhorn ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

Deploy the longhorn helm chart.
Ref: https://github.com/longhorn/charts/tree/v1.8.x/charts/longhorn

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update

kubectl create namespace longhorn-system
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system  \
  -f values.yaml

kubectl -n longhorn-system get pods

# Access longhorn UI
kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80
# Or make it permanent by setting the longhorn-frontend service type to
# LoadBalancer.
kubectl -n longhorn-system edit svc longhorn-frontend
```

## If the /mnt/longhorn is not shown

Ref: https://longhorn.io/docs/1.8.1/nodes-and-volumes/nodes/default-disk-and-node-config/

kubectl -n longhorn-system get nodes.longhorn.io
kubectl -n longhorn-system edit nodes.longhorn.io <node-name>

````
Add the following block under disks for all nodes:

```bash
    custom-disk-mnt-longhorn:           # New disk for /mnt/longhorn
      allowScheduling: true
      diskDriver: ""
      diskType: filesystem
      evictionRequested: false
      path: /mnt/longhorn                # Specify the new mount path
      storageReserved: 0                 # Adjust storageReserved if needed
      tags: []
````

## Setting the number of replicas

To set the number of replicas, edit the longhorn-storageclass configmap and
set the numberOfReplicas to the desired number.

```bash
# Set number of replica count to 1
kubectl edit configmap -n longhorn-system longhorn-storageclass
  set the numberOfReplicas: "1"
```

## Multiple storage classes for different replica counts with Longhorn

To create multiple storage classes with different replica counts, create
multiple storage class yaml files with different replica counts and apply
them. The storage class name must be different for each storage class.

```bash
# Create a new storage class with 2 replicas
kubectl apply -n longhorn-system -f longhorn-storageclass-2-replica.yaml
# Create a new storage class with 3 replicas
kubectl apply -n longhorn-system -f longhorn-storageclass-3-replica.yaml
```

# Configure AdGuard Adblocker

AdGuard is deployed in the K3S cluster for network ad protection.
A loadbalancer service is used for DNS resolution and clusterIP
and ingress for the WEBUI.

The adguard initial admin port is 3000 which is bound to the loadbalancer IP
from the local network. The AdGuard UI is accessible from the ingress
domain on the internet.

```bash
kubectl create namespace adguard
kubectl get secret wildcard-cert-secret --namespace=cert -o yaml \
  | sed 's/namespace: cert/namespace: adguard/' | kubectl apply -f -

source .env
helm install adguard \
  --set host=$ADGUARD_HOST \
  --atomic adguard-helm-chart
```

# Pocketbase Database and Authentication Backend

Pocketbase serves as the database and authentication backend for
various side projects.

```bash
# Create namespace and copy the wildcard cert secret
kubectl create namespace pocketbase
kubectl get secret wildcard-cert-secret --namespace=cert-manager -o yaml \
  | sed 's/namespace: cert-manager/namespace: pocketbase/' | kubectl apply -f -

# Deploy pocketbase using helm chart
helm install pocketbase \
  --set ingress.host=$POCKETBASE_HOST \
  --set ingress.tls.hosts[0]=$DNSNAME \
  --atomic pocketbase-helm-chart
```

It may be required to create initial user and password for the superuser.
To do that, exec into the pod and run the following command:

```bash
pocketbase superuser create email password
```

# qBittorrent with Wireguard

qBittorrent is deployed with wireguard to route traffic through a VPN tunnel.
The following packages must be installed on each node:

```bash
# On each k3s node
sudo apt update
sudo apt install -y wireguard wireguard-tools linux-headers-$(uname -r)
```

The qBittorrent is deplyoyed via helm chart. The qBittorrent deployment uses
the `media-nfs-pv` common NFS PVC for downloads. The helm chart contains both
qBittorrent and wireguard. For security, qBittorrent is not exposed outside the
network via ingress. It is accessible locally via loadbalancer IP address.

```bash
helm install qbittorrent qbittorrent-helm-chart/ --atomic
```

After deployment, verify qBittorrent is accessible on the loadbalancer IP and
port. Login to the qBittorrent UI with default credentials from the deployment
log. Change the user settings under settings/WebUI. Configure the network
interface (wg0) in settings/Advanced and set download/upload speeds in
settings/speed.

Also verify the VPM is working by executing the following command on the
qBittorrent pod:

```bash
curl ipinfo.io
```

# PostgreSQL Database (Deprecated)

`Bitnami PostgreSQL helm chart is removed in favor of CloudNativePG operator.`
The PostgreSQL database uses the bitnami postgres helm chart with one primary
and one replica statefulset, totaling 2 postgres pods.

```bash
# Add the Bitnami repo if not already added
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install PostgreSQL with these values
source .env
helm install my-postgres \
  bitnami/postgresql -f values.yaml \
  --set global.postgresql.auth.username=$POSTGRES_USER \
  --set global.postgresql.auth.password=$POSTGRES_PASSWORD \
  --set global.postgresql.auth.postgresPassword=$POSTGRES_PASSWORD \
  --atomic \
  -n postgres
```

## Connect to the Database

```bash
psql -U $POSTGRES_USER -d postgres --host 192.168.1.145 -p 5432
```

## Backup and Restore PostgreSQL Database

```bash
# To backup§
# Dump format is compressed and allows parallel restore
pg_dump -U $POSTGRES_USER -h 192.168.1.145 -p 5432 -F c \
  -f db_backup.dump postgres

# To restore
pg_restore -U $POSTGRES_USER -h 192.168.1.145 -p 5432 -d postgres db_backup.dump
```

## pgAdmin

pgAdmin provides GUI support for PostgreSQL database management. Deploy using
pgadmin.yaml manifest under postgres directory. The environment variables are
substituted from the .env file.

```bash
source .env
envsubst < postgres/pgadmin.yaml | kubectl apply -n postgres -f -
```

# Gitea Git Server

Reference:
https://gitea.com/gitea/helm-chart/
https://docs.gitea.com/installation/database-prep

Gitea is a self-hosted Git service that is deployed in the k3s cluster. The
Gitea deployment uses existing posrgres database for data storage. The Gitea
service is exposed via ingress and is accessible from the internet.

Configure a new user, database, and schema for Gitea in the postgres database.

```bash
CREATE ROLE gitea WITH LOGIN PASSWORD 'dummypassword';

CREATE DATABASE giteadb
WITH OWNER gitea
TEMPLATE template0
ENCODING UTF8
LC_COLLATE 'en_US.UTF-8'
LC_CTYPE 'en_US.UTF-8';

\c giteadb
CREATE SCHEMA gitea;
GRANT USAGE ON SCHEMA gitea TO gitea;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA gitea TO gitea;
ALTER SCHEMA gitea OWNER TO gitea;
```

Next, deploy the Gitea helm chart with the following values:

```bash
source .env
kubectl create namespace gitea
kubectl get secret wildcard-cert-secret --namespace=cert-manager -o yaml \
  | sed 's/namespace: cert-manager/namespace: gitea/' | kubectl apply -f -

# The configMap contains the app.ini file values for gitea
envsubst < gitea/configMap.yaml | kubectl apply -n gitea -f -

helm upgrade --install gitea gitea-charts/gitea -f gitea/values.yaml \
  --namespace gitea \
  --atomic \
  --set ingress.hosts[0].host=$GITEA_HOST \
  --set ingress.tls[0].hosts[0]=$DNSNAME  \
  --set gitea.admin.username=$GITEA_USER \
  --set gitea.admin.password=$GITEA_PASSWORD \
  --set gitea.admin.email=$GITEA_EMAIL \
  --set gitea.config.database.PASSWD=$POSTGRES_PASSWORD \
  --set gitea.config.database.HOST=$POSTGRES_URL
```

To scale the gitea Runner replicas, edit the `gitea-act-runner` statefulset
and set the replicas to the desired number.

```bash
kubectl edit statefulset gitea-act-runner -n gitea
```

## Configure LDAP for Gitea

Ref: https://github.com/lldap/lldap/blob/main/example_configs/gitea.md

To configure LDAP authentication for Gitea, the LDAP server must be
deployed in the k3s cluster.

LDAP config is done via the Gitea GUI. Here is the LDAP configuration

```text
Host: 192.168.1.144
Port: 3890
Bind DN: uid=admin,ou=people,dc=homelab,dc=local
Bind Password: <admin password>
User Search Base: ou=people,dc=homelab,dc=local
User Filter: (&(memberof=cn=gitea_user,ou=groups,dc=homelab,dc=local)(|(uid=%[1]s)(mail=%[1]s)))
Admin Filter: (memberOf=CN=gitea_admin,OU=groups,DC=homelab,DC=local)
User Name Attribute: uid
First Name Attribute: givenName
Last Name Attribute: sn
Email Attribute: mail
```

# Authentication Middleware Configuration for Traefik Ingress Controller

The Traefik Ingress Controller provides robust authentication capabilities
through middleware implementation. This functionality enables HTTP Basic
Authentication for services that do not include native user authentication
mechanisms.

To implement authentication, a Traefik middleware must be configured within
the target namespace. The process requires creating a secret file containing
authentication credentials (username and password). These credentials must
be base64 encoded before being integrated into the secret manifest file.

Execute the following commands to configure the authentication:

```bash
htpasswd -c traefik_auth username

echo traefik_auth | base64

source .env
envsubst < traefik-middleware/auth_secret.yaml | kubectl apply -n my-portfolio -f -
kubectl apply -f traefik-middleware/auth.yaml -n my-portfolio
```

Following middleware deployment, the authentication must be enabled by adding
the appropriate annotation to the service's Ingress object specification:

```
traefik.ingress.kubernetes.io/router.middlewares: my-portfolio-basic-auth@kubernetescrd
```

# LLDAP Authentication Server

LDAP is a protocol used to access and maintain distributed directory information.
To provide central authentication for all services, an LDAP server is deployed in the
k3s cluster. LLDAP is a lightweight LDAP server that is easy to deploy and manage.
The LLDAP server is deployed using the helm chart and is accessible via the ingress
controller.

```bash
source .env

kubectl create namespace ldap
kubectl get secret wildcard-cert-secret --namespace=cert-manager -o yaml \
  | sed 's/namespace: cert-manager/namespace: ldap/' | kubectl apply -f -

helm install ldap \
  lldap-helm-chart/ \
  --set ingress.hosts.host=$LDAP_HOST \
  --set ingress.tls[0].hosts[0]=$DNSNAME \
  --set secret.lldapUserName=$LLDAP_ADMIN_USER \
  --set secret.lldapJwtSecret=$LLDAP_JWT_SECRET \
  --set secret.lldapUserPass=$LLDAP_ADMIN_PASSWORD \
  --atomic \
  -n ldap
```

# Minio Object Storage

MinIO is a High Performance Object Storage. It is compatible with Amazon S3.
It is deployed in the k3s cluster using the helm chart.

The minio deployment is divided into two parts: the MinIO operator and the
MinIO tenant. The MinIO operator is responsible for managing the MinIO
deployment and the MinIO tenant is responsible for managing the MinIO
buckets and objects. The MinIO operator is deployed in the `minio-operator`
namespace and the MinIO tenant is deployed in the `minio` namespace.

## Deploy MinIO Operator

For deploying the MinIO operator, the MinIO operator helm chart is used.
The default values are sufficient for the operator deployment.

```bash
helm repo add minio https://operator.min.io/
helm repo update
helm install \
  --namespace minio-operator \
  --create-namespace \
  minio-operator minio/operator
```

## Deploy MinIO Tenant

The MinIO tenant is deployed in the `minio` namespace. The default values
are overridden with local values-tenant.yaml file.

```bash
source .env
kubectl create namespace minio
helm upgrade --install minio-tenant \
  minio/tenant \
  --namespace minio \
  -f minio/values-tenant.yaml \
  --set tenant.configSecret.accessKey=$MINIO_ROOT_USER \
  --set tenant.configSecret.secretKey=$MINIO_ROOT_PASSWORD \
  --set ingress.console.host=$MINIO_HOST \
  --set ingress.console.tls[0].hosts[0]=$MINIO_HOST \
  --atomic
```

# Deploy Database with CloudNativePG operator

Ref: https://cloudnative-pg.io/documentation/current/backup/#main-concepts
CloudNativePG is a Kubernetes operator that manages PostgreSQL clusters.
First, deploy the operator in the `cloudnative-pg` namespace.

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm upgrade --install cnpg \
  --namespace cnpg-system \
  --create-namespace \
  cnpg/cloudnative-pg
```

Next, deploy the PostgreSQL cluster in the `postgres` namespace with backup
configured towards the minio object storage.

```bash
source .env
kubectl create namespace immich
# First create the secret for minio access
envsubst < cloud-native-pg/secrets.yaml | kubectl apply -n immich -f -

# Then deploy the postgres cluster
envsubst < cloud-native-pg/cloudnative-pg.yaml | kubectl apply -n immich -f -

# Deploy the backup schedule
kubectl apply -f cloud-native-pg/backup.yaml -n immich
```

## Recovery from Backup

Ref: https://cloudnative-pg.io/documentation/1.20/recovery/
To recover the PostgreSQL cluster from a backup using cloudnative-pg,
there are two ways.

1. Recovery from volume snapshot - requires cnpg plugin to take the snapshot
   with kubectl.
2. Recovery from backup stored in object storage - requires the backup to be
   stored in the object storage.

To recover from a backup stored in the object storage, apply the backup-recovery.yaml template with the desired values.

```bash
source .env
envsubst < cloud-native-pg/backup-recovery.yaml | kubectl apply -n immich -f -
```

## Create a new PostgreSQL cluster from existing Database

To create a new PostgreSQL cluster from an existing database, you can use the
`create-cluster-main.yaml` as template. This template allows you to create a new
PostgreSQL cluster from an existing database by specifying the necessary
configurations and parameters in the YAML file.

This below example shows how I created a new PostgreSQL cluster from my existing
main postgres database. The new cluster is created in the `postgres` namespace.
The existing postgres database will be deprecated and removed in the future.

```bash
source .env
envsubst < cloud-native-pg/secrets.yaml | kubectl apply -n postgres -f -
envsubst < cloud-native-pg/create-cluster-main.yaml | kubectl apply -n postgres -f -
kubectl apply -f cloud-native-pg/pg-main-backup.yaml -n postgres
```

# Immich Self-hosted Photo and Video Backup Solution

Immich is a self-hosted photo and video backup solution that is deployed in
the k3s cluster. The Immich deployment uses the existing postgres database
for data storage. The Immich service is exposed via ingress and is accessible
from the internet.

To use the existing postgres database, first create a new user and database
for Immich in the postgres database.

```bash
# Log into the postgres pod
kubectl exec -it -n immich pg-backup-1 -- psql -U postgres


# Then run the following commands in the psql shell
CREATE ROLE immich WITH LOGIN PASSWORD 'dummypassword';
ALTER ROLE immich WITH SUPERUSER;
CREATE DATABASE immichdb
WITH OWNER immich
TEMPLATE template0
ENCODING UTF8
LC_COLLATE 'en_US.UTF-8'
LC_CTYPE 'en_US.UTF-8';

# Install pgvecto.rs extension
\c immichdb
CREATE EXTENSION vectors;
```

Next, create or verify local disk for immich backup

```bash
ssh dockerhost

sudo mkdir -p /media/immich
sudo mkfs.ext4 /dev/sdd
sudo mount /dev/sdd /media/immich
echo "/dev/sdd /media/immich ext4 defaults 0 2" | sudo tee -a /etc/fstab

echo "/media/immich    192.168.1.135/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
sudo exportfs -a
```

After that, create a PV and PVC for the immich backup storage.

```bash
source .env
envsubst < immich/persistence.yaml | kubectl apply -n immich -f -
```

Finally, deploy the Immich helm chart with the following values:

```bash
source .env
helm upgrade --install \
  --namespace immich immich oci://ghcr.io/immich-app/immich-charts/immich \
  -f immich/values.yaml \
  --set env.DB_USERNAME=$IMMICH_DB_USER \
  --set env.DB_PASSWORD=$IMMICH_DB_PASSWORD \
  --set env.DB_DATABASE_NAME=$IMMICH_DB_NAME \
  --set server.ingress.main.hosts[0].host=$IMMICH_HOST \
  --set server.ingress.main.tls[0].hosts[0]=$IMMICH_HOST \
  --atomic
```

# Cron Jobs for Periodic Tasks

## Update DNS Record

This cronjob updates current public IP address to the DNS record in Cloudflare.
The script to update DNS record is added to the cronjob as configmap and then
mounted as a volume in the cronjob pod. The script uses the Cloudflare API
to update the DNS record with the current public IP address.

Currently the cronjob is scheduled to run every hour.

```bash
kubectl create namespace cronjobs --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic cloudflare-dns-token \
  --from-literal=api-token=$CLOUDFLARE_TOKEN \
  -n cronjobs
kubectl apply -f cronjobs/update-dns/update_dns_config.yaml -n cronjobs
kubectl apply -f cronjobs/update-dns/update_dns_cronjob.yaml -n cronjobs
```
