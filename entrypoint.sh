#!/usr/bin/zmicro

mkdir -p /etc/gzcaas

export PLUGIN_EUNOMIA_EXPORT_DIST=/data/plugins/eunomia/exports
export PLUGIN_EUNOMIA_DOCKERFILES_PATH=/usr/local/lib/zmicro/plugins/eunomia/config/dockerfiles
export DOTENV_FILE=/etc/gzcaas/.env

function load_config() {
  log::info "[$(timestamp)] start to load config ..."

  if [ -z "$CAAS_CLIENT_ID" ]; then
    log::error "[$(timestamp)] CAAS_CLIENT_ID is required."
    return 1
  fi

  if [ -z "$CAAS_CLIENT_SECRET" ]; then
    log::error "[$(timestamp)] CAAS_CLIENT_SECRET is required."
    return 1
  fi

  if [ -z "$CAAS_SERVER_URL" ]; then
    log::error "[$(timestamp)] CAAS_SERVER_URL is required."
    return 1
  fi

  local config_url="${CAAS_SERVER_URL}/api/open/v1/agents/service/.env"
  log::info "[$(timestamp)] loading config from ${config_url} ..."
  curl \
    -H "X-Client-ID: $CAAS_CLIENT_ID" \
    -H "X-Client-Secret: $CAAS_CLIENT_SECRET" \
    -o $DOTENV_FILE \
    $config_url
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to load config from ${config_url}."
    return 1
  fi

  if [ "$LOG_LEVEL" = "debug" ]; then
    cat $DOTENV_FILE
  fi

  # check file content is empty

  source $DOTENV_FILE

  if [ -z "$CAAS_CLIENT_SERVER_NAME" ]; then
    log::error "[$(timestamp)] failed to load config from ${config_url}: $(cat $DOTENV_FILE)."
    return 1
  fi

  log::success "[$(timestamp)] succeed to load config."
}

function config_git() {
  log::info "[$(timestamp)] start to config git ..."

  #
  if [ -z "$GIT_CREDENTIALS" ]; then
    log::error "[$(timestamp)] GIT_CREDENTIALS is required."
    return 1
  fi
  echo "$GIT_CREDENTIALS" >/root/.git-credentials

  #
  if [ -z "$EUNOMIA_DOCKERFILES_GIT_REPO" ]; then
    log::error "[$(timestamp)] EUNOMIA_DOCKERFILES_GIT_REPO is required."
    return 1
  fi
  export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no"

  if [ ! -d "$PLUGIN_EUNOMIA_DOCKERFILES_PATH" ]; then
    git clone $EUNOMIA_DOCKERFILES_GIT_REPO $PLUGIN_EUNOMIA_DOCKERFILES_PATH
    if [ $? -ne 0 ]; then
      log::error "[$(timestamp)] failed to clone git repo ${EUNOMIA_DOCKERFILES_GIT_REPO}."
      return 1
    fi
  else
    cd $PLUGIN_EUNOMIA_DOCKERFILES_PATH
    git pull origin master
  fi

  log::success "[$(timestamp)] succeed to config git."
}

function config_oss() {
  log::info "[$(timestamp)] start to config oss ..."

  if [ -z "${OSS_ACCESS_KEY_ID}" ] || [ -z "${OSS_ACCESS_KEY_SECRET}" ] || [ -z "${OSS_BUCKET}" ]; then
    log::error "[$(timestamp)] OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET, OSS_BUCKET are required."
    return 1
  fi

  log::info "[$(timestamp)] starting oss service ..."

  echo "$OSS_ACCESS_KEY_ID:$OSS_ACCESS_KEY_SECRET" >/etc/passwd-ossfs
  chmod 600 /etc/passwd-ossfs

  # @TODO
  local exports_dir="$PLUGIN_EUNOMIA_EXPORT_DIST"
  mkdir -p $exports_dir

  if [ -n "${OSS_REGION}" ]; then
    log::info "[$(timestamp)] mounting oss bucket ${OSS_BUCKET} to ${exports_dir} with region(${OSS_REGION}) ..."
    ossfs -o nonempty -o url=https://${OSS_REGION}.aliyuncs.com ${OSS_BUCKET}:/data/idp/agent/exports $exports_dir
    if [ $? -ne 0 ]; then
      log::error "[$(timestamp)] failed to mount oss bucket ${OSS_BUCKET} to ${exports_dir} with region(${OSS_REGION})."
      return 1
    fi
  else
    log::info "[$(timestamp)] mounting oss bucket ${OSS_BUCKET} to ${exports_dir} ..."
    ossfs -o nonempty ${OSS_BUCKET}:/data/idp/agent/exports $exports_dir
    if [ $? -ne 0 ]; then
      log::error "[$(timestamp)] failed to mount oss bucket ${OSS_BUCKET} to ${exports_dir}."
      return 1
    fi
  fi

  log::success "[$(timestamp)] succeed to config oss."
}

function config_docker() {
  log::info "[$(timestamp)] start to config docker ..."

  if [ -z "$EUNOMIA_DOCKER_INSECURE_REGISTRY" ]; then
    log::error "[$(timestamp)] EUNOMIA_DOCKER_INSECURE_REGISTRY is required."
    return 1
  fi

  mkdir -p /etc/docker/buildx
  #
  cat >/etc/docker/buildx/buildkitd.default.toml <<EOF
[registry."${EUNOMIA_DOCKER_INSECURE_REGISTRY}"]
  http = true
EOF
  #
  cat >/etc/docker/daemon.json <<EOF
{
  "insecure-registries": [
    "http://${EUNOMIA_DOCKER_INSECURE_REGISTRY}"
  ],
  "experimental": true
}
EOF

  if [ -n "$PRELOAD_DOCKER_IMAGES" ]; then
    log::info "[$(timestamp)] starting preload images ..."
    local preload_images=$(echo $PRELOAD_DOCKER_IMAGES | tr "," "\n")
    for image in $preload_images; do
      log::info "[$(timestamp)] preload docker image: ${image} ..."
      docker pull $image &>/dev/null
    done
  fi

  log::info "[$(timestamp)] starting docker daemon ..."
  # @TODO env not work in /usr/local/bin/startup.sh
  export ENABLE_DOCKER_BUILDX=${ENABLE_DOCKER_BUILDX:-true}
  export DOCKER_BUILDER_PLATFORM=${SERVICE_DOCKER_BUILDER_PLATFORM:-linux/amd64,linux/arm64}
  export DOCKER_BUILDER_IMAGE=${DOCKER_BUILDER_IMAGE}
  #
  /usr/local/bin/startup.sh
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to start docker."
    return 1
  fi

  log::success "[$(timestamp)] succeed to config docker."
}

function config_eunomia() {
  log::info "[$(timestamp)] start to config eunomia ..."
  
  cat >/configs/plugins/eunomia/config <<EOF
PLUGIN_EUNOMIA_DOCKER_REGISTRY=${PLUGIN_EUNOMIA_DOCKER_REGISTRY}
PLUGIN_EUNOMIA_CONFIG_CENTER=${PLUGIN_EUNOMIA_CONFIG_CENTER}
PLUGIN_EUNOMIA_CONFIG_CENTER_CLIENT_ID=${PLUGIN_EUNOMIA_CONFIG_CENTER_CLIENT_ID}
PLUGIN_EUNOMIA_CONFIG_CENTER_CLIENT_SECRET=${PLUGIN_EUNOMIA_CONFIG_CENTER_CLIENT_SECRET}
# OSS
PLUGIN_EUNOMIA_EXPORT_DIR_OSS=${PLUGIN_EUNOMIA_EXPORT_DIR_OSS}
EUNOMIA_DEPLOYMENT_DEV_DOCKER_HOST=${EUNOMIA_DEPLOYMENT_DEV_DOCKER_HOST}
EUNOMIA_DEPLOYMENT_PROD_DOCKER_HOST=${EUNOMIA_DEPLOYMENT_PROD_DOCKER_HOST}
#
EUNOMIA_EXPORT_DIST_SERVER=${EUNOMIA_EXPORT_DIST_SERVER}
# DEPLOY COMPONENT
EUNOMIA_DEPLOY_COMPONENT_OSS_BUCKET=${EUNOMIA_DEPLOY_COMPONENT_OSS_BUCKET}
EUNOMIA_DEPLOY_COMPONENT_OSS_ROOT=${EUNOMIA_DEPLOY_COMPONENT_OSS_ROOT}
EUNOMIA_DEPLOY_COMPONENT_FILE_NAME=${EUNOMIA_DEPLOY_COMPONENT_FILE_NAME}
EUNOMIA_DEPLOY_COMPONENT_SERVER=${EUNOMIA_DEPLOY_COMPONENT_SERVER}
# AUTO TEST
EUNOMIA_AUTO_TEST_TRIGGER_SERVER=${EUNOMIA_AUTO_TEST_TRIGGER_SERVER}
EUNOMIA_AUTO_TEST_SERVER=${EUNOMIA_AUTO_TEST_SERVER}
#
EUNOMIA_DOCKER_BUILDX_BUILDER=${EUNOMIA_DOCKER_BUILDX_BUILDER}
EOF

  log::success "[$(timestamp)] succeed to config eunomia."
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
  # 1. load config
  load_config
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to load config."
    return 1
  fi

  # 2. config git
  config_git
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to config git."
    return 1
  fi

  # 3. config oss
  config_oss
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to config oss."
    return 1
  fi

  # 4. config docker
  config_docker
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to config docker."
    return 1
  fi

  # 5. config eunomia
  config_eunomia
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to config eunomia."
    return 1
  fi

  # 6. auto run scripts before start
  auto_run_scripts_before_start
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to run auto run scripts after start."
    return 1
  fi

  # 7. run gzcaas
  run_gzcaas
  if [ $? -ne 0 ]; then
    log::error "[$(timestamp)] failed to run gzcaas."
    return 1
  fi
}

main
