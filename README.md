# Local MongoDB Replica Set

MongoDB requires a replica set to use transactions. This repository contains a docker-compose file to start a local replica set with a single node. Although it is not necessary, you can still change this number by updating the `.env` file.

## TL; DR

### Update Environment

These environment variables required for backup task to work properly. You can dismiss the backup task, it is only to play with the database and do anything without any side effects. Restarting the `mongo` container will reset the database.

1. `MONGO__BACKUP_URI` MongoDB URI with database to connect and dump the backup.

#### Start Local Replica Set

After updating the environment variables, you can start the local replica set by starting the compose stack.

```bash
docker-compose up -d
```
