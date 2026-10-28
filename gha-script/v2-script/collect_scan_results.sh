#!/usr/bin/env bash
# collect_scan_results.sh — Download per-UBI-version × per-Python-version scan
# result tarballs from the powercore-builds COS bucket and extract them into a
# single merged v2-scan-workspace, with clear log output for each combination.
#
# Usage:
#   collect_scan_results.sh <package_name> <package_version> <workspace_dir> <run_id>
#
# Required env vars:
#   GHA_CURRENCY_SERVICE_ID_API_KEY  — IBM Cloud IAM API key
#
# For each UBI × Python version combination it tries to download two tarballs:
#   <base>-source_scanner.tar.gz  — source/ scan results
#   <base>-wheel_scanner.tar.gz   — wheel/ scan results
# where <base> = <package_name>-<package_version>-v2-scan-result-<ubi_ver>-<py_ver>
#
# Each tarball contains a single top-level directory (source/ or wheel/) and is
# extracted directly into <workspace_dir> so the paths merge correctly.
#
# The <run_id> argument (GitHub Actions run ID) ensures only tarballs uploaded
# by this specific workflow run are collected, preventing cross-run contamination
# when the same package/version has been built in multiple runs.
#
# A 404 is silently skipped (the corresponding job or scan was skipped).
# Any other HTTP error is fatal.
#
# Exits 1 if neither source nor wheel tarballs were found for any combination.
set -euo pipefail

PACKAGE_NAME="${1:?package_name required}"
PACKAGE_VERSION="${2:?package_version required}"
WORKSPACE_DIR="${3:-v2-scan-workspace}"
RUN_ID="${4:?run_id required}"

: "${GHA_CURRENCY_SERVICE_ID_API_KEY:?GHA_CURRENCY_SERVICE_ID_API_KEY is required}"

mkdir -p "${WORKSPACE_DIR}/source" "${WORKSPACE_DIR}/wheel"

echo "============================================================"
echo "  V2 Scan Results — Downloading & Collecting Artifacts"
echo "  Package  : ${PACKAGE_NAME}"
echo "  Version  : ${PACKAGE_VERSION}"
echo "  Workspace: ${WORKSPACE_DIR}"
echo "  Bucket   : powercore-gha-builds"
echo "============================================================"

# Obtain IAM token once and reuse across all downloads
echo "--- Fetching IAM token ---"
token_request=$(curl -sS -X POST https://iam.cloud.ibm.com/identity/token \
  -H "content-type: application/x-www-form-urlencoded" \
  -H "accept: application/json" \
  -d "grant_type=urn%3Aibm%3Aparams%3Aoauth%3Agrant-type%3Aapikey&apikey=${GHA_CURRENCY_SERVICE_ID_API_KEY}")

if [[ $(echo "${token_request}" | jq -r '.errorCode // empty') != "" ]]; then
  echo "ERROR: IAM token request failed."
  exit 1
fi
TOKEN=$(echo "${token_request}" | jq -r '.access_token // empty')
if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: IAM access token could not be retrieved."
  exit 1
fi
echo "OK: IAM token obtained"

BUCKET_URL="https://s3.us-east.cloud-object-storage.appdomain.cloud/powercore-gha-builds"
found_any=false

# Helper: download one tarball from COS and extract it into WORKSPACE_DIR.
# Returns 0 on success, 1 on 404 (caller treats as skip), exits on other errors.
download_and_extract() {
  local tarball="${1}"
  local object_key="${PACKAGE_NAME}/${PACKAGE_VERSION}/${RUN_ID}/${tarball}"

  echo "  Fetching: ${object_key}"
  local http_code
  http_code=$(curl -sS -w "%{http_code}" -o "${tarball}" \
    -H "Authorization: bearer ${TOKEN}" \
    "${BUCKET_URL}/${object_key}")

  if [[ "${http_code}" == "200" ]]; then
    # Each tarball contains one top-level dir (source/ or wheel/).
    # Extract with --strip-components=0 directly into WORKSPACE_DIR so the
    # directory lands at ${WORKSPACE_DIR}/source or ${WORKSPACE_DIR}/wheel.
    tar -xzf "${tarball}" -C "${WORKSPACE_DIR}"
    rm -f "${tarball}"
    echo "  OK — extracted into ${WORKSPACE_DIR}/"
    return 0
  elif [[ "${http_code}" == "404" ]]; then
    rm -f "${tarball}"
    echo "  SKIPPED — not found in COS (job or scan type may have been skipped)."
    return 1
  else
    rm -f "${tarball}"
    echo "  ERROR: COS GET failed (HTTP ${http_code})." >&2
    exit 1
  fi
}

for UBI_VER in ubi9; do
  for PY_VER in 3.10 3.11 3.12 3.13 3.14; do
    BASE="${PACKAGE_NAME}-${PACKAGE_VERSION}-v2-scan-result-${UBI_VER}-${PY_VER}"

    echo ""
    echo "------------------------------------------------------------"
    echo "  ${UBI_VER} / Python ${PY_VER}"
    echo "------------------------------------------------------------"

    combo_found=false

    if download_and_extract "${BASE}-source_scanner.tar.gz"; then
      combo_found=true
      found_any=true
    fi

    if download_and_extract "${BASE}-wheel_scanner.tar.gz"; then
      combo_found=true
      found_any=true
    fi

    if [ "${combo_found}" = "true" ]; then
      echo ""
      echo "  Wheel scan files:"
      PY_TAG="cp${PY_VER/./}"
      wheel_files=$(find "${WORKSPACE_DIR}/wheel" -maxdepth 1 -name "*${PY_TAG}*" 2>/dev/null | sort)
      if [ -n "${wheel_files}" ]; then
        while IFS= read -r f; do
          SIZE=$(du -sh "$f" | cut -f1)
          printf "    %-8s  %s\n" "${SIZE}" "$(basename "$f")"
        done <<< "${wheel_files}"
      else
        echo "    (none)"
      fi

      echo ""
      echo "  Source scan files:"
      source_files=$(find "${WORKSPACE_DIR}/source" -maxdepth 1 -type f 2>/dev/null | sort)
      if [ -n "${source_files}" ]; then
        while IFS= read -r f; do
          SIZE=$(du -sh "$f" | cut -f1)
          printf "    %-8s  %s\n" "${SIZE}" "$(basename "$f")"
        done <<< "${source_files}"
      else
        echo "    (none)"
      fi
    fi
  done
done

echo ""
echo "============================================================"
echo "  All ScanCode JSON files collected:"
echo "============================================================"
scancode_files=$(find "${WORKSPACE_DIR}/wheel" -maxdepth 1 \
  -name '*_output.json' ! -name '*_grype_output.json' 2>/dev/null | sort)
if [ -n "${scancode_files}" ]; then
  while IFS= read -r f; do
    SIZE=$(du -sh "$f" | cut -f1)
    printf "  %-8s  %s\n" "${SIZE}" "$(basename "$f")"
  done <<< "${scancode_files}"
else
  echo "  (none)"
fi
echo "============================================================"

if [ "${found_any}" = "false" ]; then
  echo ""
  echo "ERROR: No scan result tarballs were found in COS. Cannot proceed." >&2
  exit 1
fi
