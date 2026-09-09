#!/bin/bash
echo "Hello Me!" > index.html
nohup python3 -m http.server 80 > /dev/null 2>&1 &
