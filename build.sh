#!/bin/bash
# Clones the NetBox repository with git from Github and builds the Dockerfile

echo "▶️ $0 $*"

set -e

if [ "${1}x" == "x" ] || [ "${1}" == "--help" ] || [ "${1}" == "-h" ]; then
  echo "Usage: ${0} <branch> [--push]"
  echo "  branch       The branch or tag to build. Required."
  echo "  --push       Pushes the built Docker image to the registry."
  echo ""
  echo "You can use the following ENV variables to customize the build:"
  echo "  SRC_ORG     Which fork of netbox to use (i.e. github.com/\${SRC_ORG}/\${SRC_REPO})."
  echo "              Default: netbox-community"
  echo "  SRC_REPO    The name of the repository to use (i.e. github.com/\${SRC_ORG}/\${SRC_REPO})."
  echo "              Default: netbox"
  echo "  URL         Where to fetch the code from."
  echo "              Must be a git repository. Can be private."
  echo "              Default: https://github.com/\${SRC_ORG}/\${SRC_REPO}.git"
  echo "  NETBOX_PATH The path where netbox will be checkout out."
  echo "              Must not be outside of the netbox-docker repository (because of Docker)!"
  echo "              Default: .netbox"
  echo "  SKIP_GIT    If defined, git is not invoked and \${NETBOX_PATH} will not be altered."
  echo "              This may be useful, if you are manually managing the NETBOX_PATH."
  echo "              Default: undefined"
  echo "  TAG         The version part of the docker tag."
  echo "              Default:"
  echo "                When <branch>=master:  latest"
  echo "                When <branch>=develop: snapshot"
  echo "                Else:                  same as <branch>"
  echo "  IMAGE_NAMES The names used for the image including the registry"
  echo "              Used for tagging the image."
  echo "              Default: docker.io/netboxcommunity/netbox"
  echo "              Example: 'docker.io/netboxcommunity/netbox quay.io/netboxcommunity/netbox'"
  echo "  DOCKER_TAG  The name of the tag which is applied to the image."
  echo "              Useful for pushing into another registry than hub.docker.com."
  echo "              Default: \${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}:\${TAG}"
  echo "  DOCKER_SHORT_TAG The name of the short tag which is applied to the"
  echo "              image. This is used to tag all patch releases to their"
  echo "              containing version e.g. v2.5.1 -> v2.5"
  echo "              Default: \${DOCKER_REGISTRY}/\${DOCKER_ORG}/\${DOCKER_REPO}:<MAJOR>.<MINOR>"
  echo "  DOCKERFILE  The name of Dockerfile to use."
  echo "              Default: Dockerfile"
  echo "  DOCKER_FROM The base image to use."
  echo "              Default: 'ubuntu:22.04'"
  echo "  BUILDX_PLATFORMS"
  echo "            Specifies the platform(s) to build the image for."
  echo "            Example: 'linux/amd64,linux/arm64'"
  echo "            Default: 'linux/amd64'"
  echo "  BUILDX_BUILDER_NAME"
  echo "              If defined, the image build will be assigned to the given builder."
  echo "              If you specify this variable, make sure that the builder exists."
  echo "              If this value is not defined, a new builx builder with the directory name of the"
  echo "              current directory (i.e. '$(basename "${PWD}")') is created."
  echo "              Example: 'clever_lovelace'"
  echo "              Default: undefined"
  echo "  BUILDX_REMOVE_BUILDER"
  echo "              If defined (and only if BUILDX_BUILDER_NAME is undefined),"
  echo "              then the buildx builder created by this script will be removed after use."
  echo "              This is useful if you build NetBox Docker on an automated system that does"
  echo "              not manage the builders for you."
  echo "              Example: 'on'"
  echo "              Default: undefined"
  echo "  HTTP_PROXY  The proxy to use for http requests."
  echo "              Example: http://proxy.domain.tld:3128"
  echo "              Default: undefined"
  echo "  NO_PROXY    Comma-separated list of domain extensions proxy should not be used for."
  echo "              Example: .domain1.tld,.domain2.tld"
  echo "              Default: undefined"
  echo "  DEBUG       If defined, the script does not stop when certain checks are unsatisfied."
  echo "              Default: undefined"
  echo "  DRY_RUN     Prints all build statements instead of running them."
  echo "              Default: undefined"
  echo "  GH_ACTION   If defined, special 'echo' statements are enabled that set the"
  echo "              following environment variables in Github Actions:"
  echo "              - FINAL_DOCKER_TAG: The final value of the DOCKER_TAG env variable"
  echo "              Default: undefined"
  echo ""
  echo "Examples:"
  echo "  ${0} master"
  echo "              This will fetch the latest 'master' branch, build a Docker Image and tag it"
  echo "              'netboxcommunity/netbox:latest'."
  echo "  ${0} develop"
  echo "              This will fetch the latest 'develop' branch, build a Docker Image and tag it"
  echo "              'netboxcommunity/netbox:snapshot'."
  echo "  ${0} v2.6.6"
  echo "              This will fetch the 'v2.6.6' tag, build a Docker Image and tag it"
  echo "              'netboxcommunity/netbox:v2.6.6' and 'netboxcommunity/netbox:v2.6'."
  echo "  ${0} develop-2.7"
  echo "              This will fetch the 'develop-2.7' branch, build a Docker Image and tag it"
  echo "              'netboxcommunity/netbox:develop-2.7'."
  echo "  SRC_ORG=cimnine ${0} feature-x"
  echo "              This will fetch the 'feature-x' branch from https://github.com/cimnine/netbox.git,"
  echo "              build a Docker Image and tag it 'netboxcommunity/netbox:feature-x'."
  echo "  SRC_ORG=cimnine DOCKER_ORG=cimnine ${0} feature-x"
  echo "              This will fetch the 'feature-x' branch from https://github.com/cimnine/netbox.git,"
  echo "              build a Docker Image and tag it 'cimnine/netbox:feature-x'."

  if [ "${1}x" == "x" ]; then
    exit 1
  else
    exit 0
  fi
fi

source ./build-functions/gh-functions.sh

IMAGE_NAMES="${IMAGE_NAMES-docker.io/netboxcommunity/netbox}"
IFS=' ' read -ra IMAGE_NAMES <<<"${IMAGE_NAMES}"

###
# Enabling dry-run mode
###
if [ -z "${DRY_RUN}" ]; then
  DRY=""
else
  echo "⚠️ DRY_RUN MODE ON ⚠️"
  DRY="echo"
fi

gh_echo "::group::⤵️ Fetching the NetBox source code"

###
# Variables for fetching the NetBox source
###
SRC_ORG="${SRC_ORG-netbox-community}"
SRC_REPO="${SRC_REPO-netbox}"
NETBOX_BRANCH="${1}"
URL="${URL-https://github.com/${SRC_ORG}/${SRC_REPO}.git}"
NETBOX_PATH="${NETBOX_PATH-.netbox}"

###
# Fetching the NetBox source
###
if [ "${2}" != "--push-only" ] && [ -z "${SKIP_GIT}" ]; then
  REMOTE_EXISTS=$(git ls-remote --heads --tags "${URL}" "${NETBOX_BRANCH}" | wc -l)
  if [ "${REMOTE_EXISTS}" == "0" ]; then
    echo "❌ Remote branch '${NETBOX_BRANCH}' not found in '${URL}'; Nothing to do"
    gh_echo "::set-output name=skipped::true"
    exit 0
  fi
  echo "🌐 Checking out '${NETBOX_BRANCH}' of NetBox from the url '${URL}' into '${NETBOX_PATH}'"
  if [ ! -d "${NETBOX_PATH}" ]; then
    $DRY git clone -q --depth 10 -b "${NETBOX_BRANCH}" "${URL}" "${NETBOX_PATH}"
  fi

  (
    $DRY cd "${NETBOX_PATH}"
    # shellcheck disable=SC2030
    if [ -n "${HTTP_PROXY}" ]; then
      git config http.proxy "${HTTP_PROXY}"
    fi

    $DRY git remote set-url origin "${URL}"
    $DRY git fetch -qp --depth 10 origin "${NETBOX_BRANCH}"
    $DRY git checkout -qf FETCH_HEAD
    $DRY git prune
  )
  echo "✅ Checked out NetBox"
fi

gh_echo "::endgroup::"
gh_echo "::group::🧮 Calculating Values"

###
# Determining the value for DOCKERFILE
# and checking whether it exists
###
DOCKERFILE="${DOCKERFILE-Dockerfile}"
if [ ! -f "${DOCKERFILE}" ]; then
  echo "🚨 The Dockerfile ${DOCKERFILE} doesn't exist."

  if [ -z "${DEBUG}" ]; then
    exit 1
  else
    echo "⚠️ Would exit here with code '1', but DEBUG is enabled."
  fi
fi

###
# Determining the value for DOCKER_FROM
###
if [ -z "$DOCKER_FROM" ]; then
  DOCKER_FROM="ubuntu:22.04"
fi

###
# Variables for labelling the docker image
###
BUILD_DATE="$(date -u '+%Y-%m-%dT%H:%M+00:00')"

if [ -d ".git" ] && [ -z "${SKIP_GIT}" ]; then
  GIT_REF="$(git rev-parse HEAD)"
fi

# Read the project version from the `VERSION` file and trim it, see https://stackoverflow.com/a/3232433/172132
PROJECT_VERSION="${PROJECT_VERSION-$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' VERSION)}"

# Get the Git information from the netbox directory
if [ -d "${NETBOX_PATH}/.git" ] && [ -z "${SKIP_GIT}" ]; then
  NETBOX_GIT_REF=$(
    cd "${NETBOX_PATH}"
    git rev-parse HEAD
  )
  NETBOX_GIT_BRANCH=$(
    cd "${NETBOX_PATH}"
    git rev-parse --abbrev-ref HEAD
  )
  NETBOX_GIT_URL=$(
    cd "${NETBOX_PATH}"
    git remote get-url origin
  )
fi

###
# Variables for tagging the docker image
###
DOCKER_REGISTRY="${DOCKER_REGISTRY-docker.io}"
DOCKER_ORG="${DOCKER_ORG-netboxcommunity}"
DOCKER_REPO="${DOCKER_REPO-netbox}"
case "${NETBOX_BRANCH}" in
master)
  TAG="${TAG-latest}"
  ;;
develop)
  TAG="${TAG-snapshot}"
  ;;
*)
  TAG="${TAG-$NETBOX_BRANCH}"
  ;;
esac

###
# composing the final TARGET_DOCKER_TAG
###
TARGET_DOCKER_TAG="${DOCKER_TAG-${TAG}}"
TARGET_DOCKER_TAG_PROJECT="${TARGET_DOCKER_TAG}-${PROJECT_VERSION}"

###
# composing the additional DOCKER_SHORT_TAG,
# i.e. "v2.6.1" becomes "v2.6",
# which is only relevant for version tags
# Also let "latest" follow the highest version
###
if [[ "${TAG}" =~ ^v([0-9]+)\.([0-9]+)\.[0-9]+$ ]]; then
  MAJOR=${BASH_REMATCH[1]}
  MINOR=${BASH_REMATCH[2]}

  TARGET_DOCKER_SHORT_TAG="${DOCKER_SHORT_TAG-v${MAJOR}.${MINOR}}"
  TARGET_DOCKER_LATEST_TAG="latest"
  TARGET_DOCKER_SHORT_TAG_PROJECT="${TARGET_DOCKER_SHORT_TAG}-${PROJECT_VERSION}"
  TARGET_DOCKER_LATEST_TAG_PROJECT="${TARGET_DOCKER_LATEST_TAG}-${PROJECT_VERSION}"
fi

IMAGE_NAME_TAGS=()
for IMAGE_NAME in "${IMAGE_NAMES[@]}"; do
  IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_TAG}")
  IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_TAG_PROJECT}")
done
if [ -n "${TARGET_DOCKER_SHORT_TAG}" ]; then
  for IMAGE_NAME in "${IMAGE_NAMES[@]}"; do
    IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_SHORT_TAG}")
    IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_SHORT_TAG_PROJECT}")
    IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_LATEST_TAG}")
    IMAGE_NAME_TAGS+=("${IMAGE_NAME}:${TARGET_DOCKER_LATEST_TAG_PROJECT}")
  done
fi

gh_env "FINAL_DOCKER_TAG=${IMAGE_NAME_TAGS[0]}"

###
# Checking if the build is necessary,
# meaning build only if one of those values changed:
# - base image digest
# - netbox git ref (Label: netbox.git-ref)
# - netbox-docker git ref (Label: org.opencontainers.image.revision)
###
# Load information from registry (only for docker.io)
SHOULD_BUILD="false"
BUILD_REASON=""
if [ -z "${GH_ACTION}" ]; then
  # Asuming non Github builds should always proceed
  SHOULD_BUILD="true"
  BUILD_REASON="${BUILD_REASON} interactive"
elif [[ "${IMAGE_NAME_TAGS[0]}" = docker.io* ]]; then
  source ./build-functions/get-public-image-config.sh
  IFS=':' read -ra DOCKER_FROM_SPLIT <<<"${DOCKER_FROM}"
  if ! [[ ${DOCKER_FROM_SPLIT[0]} =~ .*/.* ]]; then
    # Need to use "library/..." for images the have no two part name
    DOCKER_FROM_SPLIT[0]="library/${DOCKER_FROM_SPLIT[0]}"
  fi
  IFS='/' read -ra ORG_REPO <<<"${IMAGE_NAMES[0]}"
  echo "Checking labels for '${ORG_REPO[1]}' and '${ORG_REPO[2]}'"
  BASE_LAST_LAYER=$(get_image_last_layer "${DOCKER_FROM_SPLIT[0]}" "${DOCKER_FROM_SPLIT[1]}")
  mapfile -t IMAGES_LAYERS_OLD < <(get_image_layers "${ORG_REPO[1]}"/"${ORG_REPO[2]}" "${TAG}")
  NETBOX_GIT_REF_OLD=$(get_image_label netbox.git-ref "${ORG_REPO[1]}"/"${ORG_REPO[2]}" "${TAG}")
  GIT_REF_OLD=$(get_image_label org.opencontainers.image.revision "${ORG_REPO[1]}"/"${ORG_REPO[2]}" "${TAG}")

  if ! printf '%s\n' "${IMAGES_LAYERS_OLD[@]}" | grep -q -P "^${BASE_LAST_LAYER}\$"; then
    SHOULD_BUILD="true"
    BUILD_REASON="${BUILD_REASON} debian"
  fi
  if [ "${NETBOX_GIT_REF}" != "${NETBOX_GIT_REF_OLD}" ]; then
    SHOULD_BUILD="true"
    BUILD_REASON="${BUILD_REASON} netbox"
  fi
  if [ "${GIT_REF}" != "${GIT_REF_OLD}" ]; then
    SHOULD_BUILD="true"
    BUILD_REASON="${BUILD_REASON} netbox-docker"
  fi
else
  SHOULD_BUILD="true"
  BUILD_REASON="${BUILD_REASON} no-check"
fi

if [ "${SHOULD_BUILD}" != "true" ]; then
  echo "Build skipped because sources didn't change"
  echo "::set-output name=skipped::true"
  exit 0 # Nothing to do -> exit
else
  gh_echo "::set-output name=skipped::false"
fi
gh_echo "::endgroup::"

###
# Build the image
###
gh_echo "::group::🏗 Building the image"
###
# Composing all arguments for `docker build`
###
DOCKER_BUILD_ARGS=(
  --pull
  --target main
  -f "${DOCKERFILE}"
)
for IMAGE_NAME in "${IMAGE_NAME_TAGS[@]}"; do
  DOCKER_BUILD_ARGS+=(-t "${IMAGE_NAME}")
done

# --label
DOCKER_BUILD_ARGS+=(
  --label "netbox.original-tag=${TARGET_DOCKER_TAG_PROJECT}"
  --label "org.opencontainers.image.created=${BUILD_DATE}"
  --label "org.opencontainers.image.version=${PROJECT_VERSION}"
)
if [ -d ".git" ] && [ -z "${SKIP_GIT}" ]; then
  DOCKER_BUILD_ARGS+=(
    --label "org.opencontainers.image.revision=${GIT_REF}"
  )
fi
if [ -d "${NETBOX_PATH}/.git" ] && [ -z "${SKIP_GIT}" ]; then
  DOCKER_BUILD_ARGS+=(
    --label "netbox.git-branch=${NETBOX_GIT_BRANCH}"
    --label "netbox.git-ref=${NETBOX_GIT_REF}"
    --label "netbox.git-url=${NETBOX_GIT_URL}"
  )
fi
if [ -n "${BUILD_REASON}" ]; then
  BUILD_REASON=$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<<"$BUILD_REASON")
  DOCKER_BUILD_ARGS+=(--label "netbox.build-reason=${BUILD_REASON}")
fi

# --build-arg
DOCKER_BUILD_ARGS+=(--build-arg "NETBOX_PATH=${NETBOX_PATH}")

if [ -n "${DOCKER_FROM}" ]; then
  DOCKER_BUILD_ARGS+=(--build-arg "FROM=${DOCKER_FROM}")
fi
# shellcheck disable=SC2031
if [ -n "${HTTP_PROXY}" ]; then
  DOCKER_BUILD_ARGS+=(--build-arg "http_proxy=${HTTP_PROXY}")
  DOCKER_BUILD_ARGS+=(--build-arg "https_proxy=${HTTPS_PROXY}")
fi
if [ -n "${NO_PROXY}" ]; then
  DOCKER_BUILD_ARGS+=(--build-arg "no_proxy=${NO_PROXY}")
fi

DOCKER_BUILD_ARGS+=(--platform "${BUILDX_PLATFORM-linux/amd64}")
if [ "${2}" == "--push" ]; then
  # output type=docker does not work with pushing
  DOCKER_BUILD_ARGS+=(
    --output=type=image
    --push
  )
else
  DOCKER_BUILD_ARGS+=(
    --output=type=docker
  )
fi

###
# Building the docker image
###
if [ -z "${BUILDX_BUILDER_NAME}" ]; then
  BUILDX_BUILDER_NAME="$(basename "${PWD}")"
fi
if ! docker buildx ls | grep --quiet --word-regexp "${BUILDX_BUILDER_NAME}"; then
  echo "👷  Creating new Buildx Builder '${BUILDX_BUILDER_NAME}'"
  $DRY docker buildx create --name "${BUILDX_BUILDER_NAME}"
  BUILDX_BUILDER_CREATED="yes"
fi

echo "🐳 Building the Docker image '${TARGET_DOCKER_TAG_PROJECT}'."
echo "    Build reason set to: ${BUILD_REASON}"
$DRY docker buildx \
  --builder "${BUILDX_BUILDER_NAME}" \
  build \
  "${DOCKER_BUILD_ARGS[@]}" \
  .
echo "✅ Finished building the Docker images"
gh_echo "::endgroup::" # End group for Build

gh_echo "::group::🏗 Image Labels"
echo "🔎 Inspecting labels on '${IMAGE_NAME_TAGS[0]}'"
$DRY docker inspect "${IMAGE_NAME_TAGS[0]}" --format "{{json .Config.Labels}}" | jq
gh_echo "::endgroup::"

gh_echo "::group::🏗 Clean up"
if [ -n "${BUILDX_REMOVE_BUILDER}" ] && [ "${BUILDX_BUILDER_CREATED}" == "yes" ]; then
  echo "👷  Removing Buildx Builder '${BUILDX_BUILDER_NAME}'"
  $DRY docker buildx rm "${BUILDX_BUILDER_NAME}"
fi
gh_echo "::endgroup::"
