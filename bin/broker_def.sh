#!/bin/bash

pubcmd=mosquitto_pub
pubhost="-h gaspberrypi.fritz.box"
pubtopic="-t svcmon"
pubopts="${pubhost} ${pubtopic}"
