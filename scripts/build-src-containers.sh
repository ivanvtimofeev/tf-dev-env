#!/bin/bash

[ -n "$DEBUG" ] && set -x

my_file="$(readlink -e "$0")"
my_dir="$(dirname $my_file)"

source ${my_dir}/../common/common.sh
source ${my_dir}/../common/functions.sh

echo "INFO: Build sources containers"
if [[ -z "${REPODIR}" ]] ; then
  echo "ERROR: REPODIR Must be set for build src containers"
  exit 1
fi

buildsh=${REPODIR}/contrail-container-builder/containers/build.sh
if ! [[ -x "${buildsh}" ]] ; then
  echo "ERROR: build.sh tool from contrail-container-builder is not available in ${REPODIR} or is not executable"
  exit 1
fi

publish_list_file=${PUBLISH_LIST_FILE:-"${my_dir}/../src_containers_to_publish"}
if ! [[ -f "${publish_list_file}" ]] ; then
  echo "ERROR: targets for build as src containers must be listed at ${publish_list_file}"
  exit 1
fi

dockerfile_template=${DOCKERFILE_TEMPLATE:-"${my_dir}/Dockerfile.src.tmpl"}
if ! [[ -f "${dockerfile_template}" ]] ; then
  echo "ERROR: Dockerfile template ${dockerfile_template} is not available."
  exit 1
fi

function build_container() {
  local line=$1
  CONTRAIL_CONTAINER_NAME=${line}-src ${buildsh} ${REPODIR}/${line}
  rm -f ${REPODIR}/${line}/Dockerfile
}

jobs=""
echo "INFO: ===== Start Build Containers at $(date) ====="
while IFS= read -r line; do
if ! [[ "$line" =~ ^\#.*$ ]] ; then
  if ! [[ "$line" =~ ^[\-0-9a-zA-Z\/_.]+$ ]] ; then
    echo "ERROR: Directory name ${line} must contain only latin letters, digits or '.', '-', '_' symbols  "
    exit 1
  fi

  if ! [[ -d "${REPODIR}/${line}" ]] ; then
    echo "ERROR: not found directory ${REPODIR}/${line} mentioned in ${publish_list_file}"
    exit 1
  fi

  echo "INFO: Pack $line sources to container ${line}-src ${buildsh}"
  cp -f ${dockerfile_template} ${REPODIR}/${line}/Dockerfile
  build_container ${line} &
  jobs+=" $!"
fi
done < ${publish_list_file}

res=0
for i in $jobs ; do
  wait $i || res=1
done

if [[ $res == 1 ]] ; then
  echo "ERROR: There were some errors when source containers builded."
  exit 1
else
  echo "INFO: All source containers has been successfuly built."
  exit 0
fi

