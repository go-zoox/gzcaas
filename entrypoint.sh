#!/usr/bin/zmicro

export PLUGIN_EUNOMIA_EXPORT_DIST=/data/plugins/eunomia/exports

function start_oss_service() {
  log::info "[$(timestamp)] starting oss service ..."

  if [ -z "${OSS_ACCESS_KEY_ID}" ] || [ -z "${OSS_ACCESS_KEY_SECRET}" ] || [ -z "${OSS_BUCKET}" ]; then
    log::error "[$(timestamp)] OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET, OSS_BUCKET are required."
    return 1
  fi

  echo "$OSS_ACCESS_KEY_ID:$OSS_ACCESS_KEY_SECRET" >/etc/passwd-s3fs
  chmod 600 /etc/passwd-s3fs

  # @TODO
  local exports_dir="$PLUGIN_EUNOMIA_EXPORT_DIST"
  mkdir -p $exports_dir

  log::info "[$(timestamp)] mounting oss bucket ${OSS_BUCKET} to ${exports_dir} ..."
  ossfs -o nonempty ${OSS_BUCKET}:/data/idp/agent/exports $exports_dir
}

function preload_docker_images() {
  if [ -z "$PRELOAD_DOCKER_IMAGES" ]; then
    return
  fi

  log::info "[$(timestamp)] starting preload images ..."
  local preload_images=$(echo $PRELOAD_DOCKER_IMAGES | tr "," "\n")
  for image in $preload_images; do
    log::info "[$(timestamp)] preload docker image: ${image} ..."
    docker pull $image &>/dev/null
  done
}

function auto_run_scripts_before_start() {
  local scripts_dir="/etc/gzcaas/auto_run_scripts"
  if [ ! -d "$scripts_dir" ]; then
    return
  fi

  log::info "[$(timestamp)] running auto run scripts after start ..."
  for script in $(ls $scripts_dir); do
    log::info "[$(timestamp)] running script: ${script} ..."
    sh $scripts_dir/$script
  done
}

function run_gzcaas() {
  log::info "[$(timestamp)] running gzcaas ..."
  gzcaas server
}

function main() {
  start_oss_service
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to start oss service."
    return 1
  fi

  preload_docker_images
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to preload docker images."
    return 1
  fi

  auto_run_scripts_before_start
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to run auto run scripts after start."
    return 1
  fi

  run_gzcaas
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to run gzcaas."
    return 1
  fi
}

main
