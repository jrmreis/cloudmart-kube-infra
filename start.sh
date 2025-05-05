#!/bin/bash
# From your local machine
nohup ansible-playbook -i inventory.ini deploy-cloudmart.yml >> ../start.log 2>&1 &
