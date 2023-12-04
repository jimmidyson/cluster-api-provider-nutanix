#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

repo_root="${repo_root:-$(git rev-parse --show-toplevel)}"
module_root="${repo_root}"

module_name="$(cd "${module_root}" && go list -m)"

# Create a fake gopath
fake_gopath="$(mktemp -d)"

# Always cleanup.
cleanup_gopath() {
  rm -rf "$fake_gopath" || true
  rm -rf "${module_root}/vendor" || true
}
trap cleanup_gopath EXIT

# Generate conversion functions
conversion_inputs=(
  api/v1alpha4
  api/v1beta1
)

# turn off module mode before running the generators
# https://github.com/kubernetes/code-generator/issues/69
# we also need to populate vendor
export GO111MODULE="on"
go mod vendor
export GO111MODULE="off"

fake_repopath=${fake_gopath}/src/${module_name}
mkdir -p "$(dirname "${fake_repopath}")" && ln -s "${module_root}" "${fake_repopath}"
export GOPATH="${fake_gopath}"
cd "${fake_repopath}"

gen-conversions() {
  if [ -z "${conversion_inputs-}" ]; then
    return # nothing to do here
  fi
  echo "Generating conversion functions..." >&2
  prefixed_inputs=("${conversion_inputs[@]/#/$module_name/}")
  joined=$(
    IFS=$','
    echo "${prefixed_inputs[*]}"
  )
  conversion-gen \
    --go-header-file "${repo_root}/hack/boilerplate.go.txt" \
    --input-dirs "$joined" \
    -O zz_generated.conversion
}

gen-conversions
