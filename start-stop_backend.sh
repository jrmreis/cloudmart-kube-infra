#!/bin/bash

docker stop cloudmart-backend-container
docker rm cloudmart-backend-container
docker ps
cd /home/ec2-user/challenge-day2/backend && docker build -t cloudmart-backend .
cd /home/ec2-user/challenge-day2/backend && docker run -d -p 5000:5000 --env-file .env --name cloudmart-backend-container cloudmart-backend
docker ps
