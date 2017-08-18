#!/bin/bash
set -e

git config --global user.email "analytics@harrys.com"
git config --global user.name "Analytics Notebooks"
git clone https://${GH_TOKEN}:x-oauth-basic@github.com/harrystech/harrys-analytics.git ./harrys-analytics
cd ./harrys-analytics

echo "*:*:*:harrys_analytics:${DB_PASSWORD}" >> ~/.pgpass
chmod 0600 ~/.pgpass

bash start-notebook.sh --NotebookApp.password=${NOTEBOOK_PASSWORD}
