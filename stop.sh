#!/bin/bash
nohup ansible-playbook -i inventory.ini cleanup-cloudmart.yml >> ../cleanup.log 2>&1 &
