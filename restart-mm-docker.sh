#!/bin/bash
sudo docker-compose -f docker-compose.yml -f docker-compose.nginx.yml down
sleep 5
sudo docker-compose -f docker-compose.yml -f docker-compose.nginx.yml up -d
