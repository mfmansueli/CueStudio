#!/bin/zsh
# usage: appshot.sh <out.png> <wait seconds> <launch args...>
# Launches the app on the simulator with the launch arguments (Debug only, `LaunchOptions.swift`) and saves a picture after the wait.
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
UDID=${SIMULATOR_UDID:?set SIMULATOR_UDID to a booted iPhone 390 x 844 pt simulator}
OUT=$1; WAIT=$2; shift 2
xcrun simctl terminate $UDID com.cuestudioteleprompter >/dev/null 2>&1
xcrun simctl launch $UDID com.cuestudioteleprompter "$@" >/dev/null 2>&1
sleep $WAIT
xcrun simctl io $UDID screenshot --type=png "$OUT" >/dev/null 2>&1
