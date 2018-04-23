#!/bin/bash
# Generates the gobuild

set -e
set -o pipefail

ROOT_PACKAGE="$1"
SHARD="$2"
if [ "$ROOT_PACKAGE" == "" -o "$SHARD" == "" ]; then
  echo "No shard provided"
  exit 1
fi

ROOT="src/$ROOT_PACKAGE"
SHARD_PACKAGE="$ROOT_PACKAGE"
if [[ "$SHARD" != "." ]]; then
    SHARD_PACKAGE="$ROOT_PACKAGE/$SHARD"
fi

PWD=$(pwd)
export GOPATH="$PWD"
DEPS=$(go list -f '{{.ImportPath}}{{range .Deps}}
{{.}}{{end}}' "$SHARD_PACKAGE" | sed -e 's#$#/*#' | sort | uniq)

# Look for LDFlags of the form -L/path/to/root/path/to/lib
# and extract them into patterns of the form 'path/to/lib/*'
CGO_DIRS=$(go list -f '{{range .CgoLDFLAGS}}
{{.}}{{end}}' "$SHARD_PACKAGE" | sed -n -e "s#-L$PWD/##p" | sed -e 's#$#/*#')

# Filter out the built-in imports
IMPORTS=$(grep -e "[.]" <<< "$DEPS" || echo "")
DIRS=$(sed -e 's#^#src/#' <<< "$IMPORTS")

EXTRA_DIRS=""
if [[ -e $ROOT/.windmill/extra_go_deps.txt ]]; then
    EXTRA_DIRS=`cat $ROOT/.windmill/extra_go_deps.txt`
fi

ALL_DIRS="$DIRS
$EXTRA_DIRS
$CGO_DIRS
!**/*_test.go"

BIN_NAME=$(basename "$SHARD_PACKAGE")

PATTERNS=$(echo "$ALL_DIRS" | grep -Ev "^$" | jq -R '[.]' | jq -s 'add')
cat <<JSON
{
  "deps": $PATTERNS,
  "argv": ["bash", "-c",
           "export GOPATH=\`pwd\`; export GOCACHE=\`pwd\`/gocache; set -e -o pipefail; cd $ROOT; go install -i $SHARD_PACKAGE;"],
  "artifacts": [{"path": "pkg"}],
  "snapshot": {"matcher": {"patterns": ["bin/$BIN_NAME"]}}
}
JSON
