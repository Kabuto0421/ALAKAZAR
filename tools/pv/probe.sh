#!/bin/sh
# usage: tools/pv/probe.sh <shot> [seconds]  -> build/pv/<shot>.avi
SHOT=$1
mkdir -p build/pv
xvfb-run -a "${GODOT:-godot}" --rendering-driver opengl3 --path . --write-movie build/pv/$SHOT.avi --fixed-fps 30 --resolution 1728x1080 --script res://tools/pv/pv_shot.gd -- $SHOT 2>&1 | grep -E "^PV|SCRIPT|ERROR: no such|Parse" 
