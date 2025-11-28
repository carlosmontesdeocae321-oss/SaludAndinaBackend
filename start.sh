#!/usr/bin/env bash
set -e
# Move to backend folder, install production deps and start
cd clinica_backend
npm install --production
npm start
