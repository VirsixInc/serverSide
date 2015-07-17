#!/bin/bash

while true
do
if [ ! `pgrep prodDevry/app.coffee` ] ; then
coffee /var/www/prodDevry/app.coffee
fi
sleep 30
done
