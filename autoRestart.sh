#!/bin/bash

while true
do
if [ ! `pgrep DEVRY_TEST/app.coffee` ] ; then
coffee ../app.coffee
fi
sleep 30
done
