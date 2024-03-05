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

  run_gzcaas
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to run gzcaas."
    return 1
  fi
}

main
