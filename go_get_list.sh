#!/bin/bash
#
# Grabs the direct external dependencies of the current package,
# so we can run go get on them.
#
# We want to split this into two separate runs:
# one that uses the whole snapshot as input and outputs
# a list of dependencies, and another that fetches them.
#
# This makes it easier to recycle.

set -e
set -o pipefail

ROOT_PACKAGE="$1"
if [ "$ROOT_PACKAGE" == "" ]; then
  echo "No shard provided"
  exit 1
fi

export GOPATH=$(pwd)
DEPS=$(go list -f '{{range .Imports}}
{{.}}{{end}}{{range .TestImports}}
{{.}}{{end}}{{range .XTestImports}}
{{.}}{{end}}' $ROOT_PACKAGE/... | sed -e '/^$/d' | sort | uniq)

# Remove deps from this package, and deps that do not
# have a dot in the name (because they are built-ins)
EXTERNAL_DEPS=$(echo "$DEPS" | grep -v $ROOT_PACKAGE | grep -e "[.]")
echo "$EXTERNAL_DEPS"

