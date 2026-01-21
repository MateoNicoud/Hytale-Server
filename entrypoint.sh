#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="/data"
SERVER_DIR="${DATA_DIR}/server"
DL_DIR="${DATA_DIR}/downloads"
DL_BASE="/opt/hytale/downloader"

mkdir -p "${SERVER_DIR}" "${DL_DIR}"

sanitize() {
  echo -n "$1" | tr -d '\r' | xargs
}

SERVER_IP="$(sanitize "${SERVER_IP:-0.0.0.0}")"
SERVER_PORT="$(sanitize "${SERVER_PORT:-5520}")"

JAVA_XMS="$(sanitize "${JAVA_XMS:-4G}")"
JAVA_XMX="$(sanitize "${JAVA_XMX:-6G}")"
JAVA_GC_OPTS="$(sanitize "${JAVA_GC_OPTS:-}")"
JAVA_EXTRA_OPTS="$(sanitize "${JAVA_EXTRA_OPTS:-}")"

ENABLE_AOT="$(sanitize "${ENABLE_AOT:-true}")"
AOT_FILE="$(sanitize "${AOT_FILE:-HytaleServer.aot}")"

DISABLE_SENTRY="$(sanitize "${DISABLE_SENTRY:-false}")"
AUTH_MODE="$(sanitize "${AUTH_MODE:-authenticated}")"
EXTRA_ARGS="$(sanitize "${EXTRA_ARGS:-}")"
PATCHLINE="$(sanitize "${PATCHLINE:-}")"
SKIP_UPDATE_CHECK="$(sanitize "${SKIP_UPDATE_CHECK:-false}")"

case "${AUTH_MODE}" in
  authenticated|offline) ;;
  *)
    echo "Invalid AUTH_MODE: '${AUTH_MODE}' (authenticated|offline)"
    exit 1
    ;;
esac

pick_downloader() {
  local arch bin
  arch="$(uname -m)"
  case "${arch}" in
    x86_64|amd64)
      bin="$(ls -1 "${DL_BASE}"/hytale-downloader-* 2>/dev/null | grep -E 'linux-(amd64|x86_64)' | head -n1 || true)"
      ;;
    aarch64|arm64)
      bin="$(ls -1 "${DL_BASE}"/hytale-downloader-* 2>/dev/null | grep -E 'linux-(arm64|aarch64)' | head -n1 || true)"
      ;;
    *)
      echo "Unsupported architecture: ${arch}"
      exit 1
      ;;
  esac

  if [[ -z "${bin}" ]]; then
    bin="$(ls -1 "${DL_BASE}"/hytale-downloader 2>/dev/null | head -n1 || true)"
  fi

  if [[ -z "${bin}" ]]; then
    echo "Downloader not found in ${DL_BASE}"
    exit 1
  fi

  echo "${bin}"
}

need_server_files() {
  [[ ! -f "${SERVER_DIR}/HytaleServer.jar" || ! -f "${SERVER_DIR}/Assets.zip" ]]
}

download_and_extract() {
  local dl_bin args zipfile extract_dir
  dl_bin="$(pick_downloader)"

  echo "Downloading server binaries (via downloader)."
  echo "On first run, a device authentication prompt may be required in the attached terminal."

  args=()
  [[ -n "${PATCHLINE}" ]] && args+=("-patchline" "${PATCHLINE}")
  [[ "${SKIP_UPDATE_CHECK}" == "true" ]] && args+=("-skip-update-check")

  zipfile="${DL_DIR}/game.zip"
  args+=("-download-path" "${zipfile}")

  "${dl_bin}" "${args[@]}"

  extract_dir="${DL_DIR}/extract"
  rm -rf "${extract_dir}"
  mkdir -p "${extract_dir}"
  unzip -q -o "${zipfile}" -d "${extract_dir}"

  if [[ ! -d "${extract_dir}/Server" || ! -f "${extract_dir}/Assets.zip" ]]; then
    echo "Unexpected archive layout. Contents:"
    ls -la "${extract_dir}"
    exit 1
  fi

  cp -a "${extract_dir}/Server/." "${SERVER_DIR}/"
  cp -a "${extract_dir}/Assets.zip" "${SERVER_DIR}/Assets.zip"

  echo "Server binaries are ready in ${SERVER_DIR}"
}

build_java_cmd() {
  local java_opts=()
  java_opts+=("-Xms${JAVA_XMS}" "-Xmx${JAVA_XMX}")

  if [[ -n "${JAVA_GC_OPTS}" ]]; then
    # shellcheck disable=SC2206
    java_opts+=(${JAVA_GC_OPTS})
  fi
  if [[ -n "${JAVA_EXTRA_OPTS}" ]]; then
    # shellcheck disable=SC2206
    java_opts+=(${JAVA_EXTRA_OPTS})
  fi

  if [[ "${ENABLE_AOT}" == "true" && -f "${SERVER_DIR}/${AOT_FILE}" ]]; then
    java_opts+=("-XX:AOTCache=${AOT_FILE}")
  fi

  local server_args=()
  server_args+=("--assets" "Assets.zip")
  server_args+=("--bind" "${SERVER_IP}:${SERVER_PORT}")
  server_args+=("--auth-mode" "${AUTH_MODE}")

  if [[ "${DISABLE_SENTRY}" == "true" ]]; then
    server_args+=("--disable-sentry")
  fi

  if [[ -n "${EXTRA_ARGS}" ]]; then
    # shellcheck disable=SC2206
    server_args+=(${EXTRA_ARGS})
  fi

  echo "java ${java_opts[*]} -jar HytaleServer.jar ${server_args[*]}"
}

main() {
  if need_server_files; then
    download_and_extract
  else
    echo "Server binaries already present."
  fi

  cd "${SERVER_DIR}"

  echo "Starting server."
  cmd="$(build_java_cmd)"
  echo "> ${cmd}"
  exec bash -lc "${cmd}"
}

main "$@"
