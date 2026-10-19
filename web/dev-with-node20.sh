#!/bin/bash
export PATH="/home/demo/node-v20.18.1-linux-x64/bin:$PATH"
cd "$(dirname "$0")"
exec npm run dev
