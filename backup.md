# Backup Net Box on the Docker Host

This script is intended to backup a running netbox Docker instance

## Backup the Database 

### Get the Backup in a  Host Storage

mkdir -p /backup/netbox

/etc/fstab
# NetBox Backup Destination
10.0.10.50:/docker/netbox-backup /backup/netbox nfs rw,hard,intr,rsize=8192,wsize=8192,timeo=14,noexec,nosuid 0 0

On the Docker Host
docker exec -it netbox-docker_postgres_1 pg_dump -U netbox -d netbox > /backup/netbox/netbox_`date +%d-%m-%Y_%H_%M_%S`.sql


https://forum.level1techs.com/t/netbox-ipam-dcim-guide/132435/3
