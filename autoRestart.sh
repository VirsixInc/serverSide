#!/bin/bash

while true
do
if [ ! `pgrep prodDevry/app.coffee` ] ; then
coffee ../app.coffee
fi
sleep 30
done
