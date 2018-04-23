#!/bin/bash
#
# Fetches the dependencies as a list of arguments.
#
# We have a special whitelist that gives this script network access.

set -ex

export GOPATH=$(pwd)
go get -v "$@"
