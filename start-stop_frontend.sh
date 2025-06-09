#!/bin/bash

docker stop cloudmart-frontend-container
docker rm cloudmart-frontend-container
docker ps
cd /home/ec2-user/challenge-day2/frontend && docker build -t cloudmart-frontend .
cd /home/ec2-user/challenge-day2/frontend && docker run -d -p 5001:5001 --env-file .env --name cloudmart-frontend-container cloudmart-frontend
docker ps
