#!/usr/bin/env python
# Generates the gotest composition, given the shard as an argument
import sys
import os
import json
import fnmatch

from subprocess import check_output

root_package = sys.argv[1]
shard = sys.argv[2]
timeout = sys.argv[3]
root = os.path.join("src", root_package)

def go_list(template, paths):
  """Run go list and return the output as an array of strings.

  Args:
    template (str): The template to use to format the output
    paths (list): A list of paths to analyze
  Returns:
    list of str
  """
  return check_output(["go", "list", "-f", template] + list(paths)).decode('utf-8').splitlines()

def path_has_non_test_go_files(path):
  for _, _, filenames in os.walk(path):
    for filename in fnmatch.filter(filenames, '*.go'):
      if not filename.endswith("_test.go"):
        return True
  return False

def patternify(package):
  return os.path.join(package, "*")

def is_built_in_package(package):
  # This is a dumb heuristic that assumes remote packages have "." in the package
  # name but built-in packages do not.
  return package.find(".") == -1

def clean_up_package(package):
  # This function used to do some golang.org munging that appears to be fixed in
  # newer versions of Go
  return package

def deps(root_package, shard):
  template = """{{.ImportPath}}{{range .Deps}}
{{.}}{{end}}"""
  path = os.path.join(root_package, shard)
  output = go_list(template, [path])
  deps = [patternify(clean_up_package(p)) for p in output]
  deps = [p for p in deps if not is_built_in_package(p)]
  return deps

def test_imports(root_package, shard):
  template = """{{range .TestImports}}{{.}}
{{end}}{{range .XTestImports}}{{.}}
{{end}}"""
  path = root_package + "/" + shard
  return go_list(template, [path])

cwd = os.getcwd()
os.environ["GOPATH"] = cwd

ti = test_imports(root_package, shard)
user_packages = [i for i in ti if not is_built_in_package(i)]
all_deps = set(deps(root_package, shard))

if user_packages:
  template = """{{.ImportPath}}{{range .Deps}}
{{.}}{{end}}"""
  for d in go_list(template, user_packages):
    clean = clean_up_package(d)
    if not is_built_in_package(clean):
      all_deps.add(patternify(clean))

sorted_deps = sorted(all_deps)
fully_qualified_deps = ["src/" + d for d in sorted_deps]
fully_qualified_deps.insert(0, os.path.join(root, shard, "testdata", "**"))

extra_dirs_path = os.path.join(root, ".windmill", "extra_go_deps.txt")
if os.path.isfile(extra_dirs_path):
  with open(extra_dirs_path) as f:
    for d in f:
      cleaned = d.strip()
      if cleaned:
        fully_qualified_deps.append(cleaned)

me = sys.argv[0]
if me.startswith(cwd):
  me = me[len(cwd):]
fully_qualified_deps.append(me)

install_path = os.path.join(root_package, shard)
install_command = ""
if path_has_non_test_go_files(os.path.join("src", install_path)):
  install_command = "go install -i " + install_path + ";"

prelude = 'export GOPATH=`pwd`; export GOCACHE=`pwd`/gocache; set -e -o pipefail;'
json_out = {
  "deps": fully_qualified_deps,
  # We 'cd' into the workspace because Go projects typically want the error
  # messages printed relative to the package root, not relative to the GOPATH.
  "argv": ["bash", "-c",
           r'%s cd %s; %s go test -timeout %s %s/%s' %
           (prelude, root, install_command, timeout, root_package, shard)],
  "artifacts": [{"path": "pkg"}]
}

sys.stdout.write(json.dumps(json_out, indent=2, sort_keys=True))
