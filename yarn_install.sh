#!/bin/bash
#
# Runs `yarn install`
#
# We have a special whitelist that gives this script network access.

set -ex

yarn install --frozen-lockfile --cache-folder .yarn-cache
