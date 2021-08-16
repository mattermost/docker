# Migration without script
## Checking disk space
First you should check the available disk space with commands like `df` and `du`. You
should have at least two times the size of your *volumes/db* folder in free space as we need to copy it.

```
cd mattermost-docker
sudo df -h
sudo du -sh volumes/db
```

If your installation resides on a Btrfs with snapshots it's advisable to run the following commands:
```
sudo btrfs filesystem df -h volumes
sudo btrfs filesystem du -s volumes/db
```

## Backup database
For a database backup you can use two different methods.
```
cd mattermost-docker
mkdir backup
mv $PWD/{.circleci,.git,.gitignore,.travis.yml,app,contrib,db,web,CONTRIBUTING.md,LICENSE,MAINTAINANCE.md,README.md,docker-compose.yml} backup

git init
git remote add origin https://github.com/mattermost/docker
git pull origin main
```
