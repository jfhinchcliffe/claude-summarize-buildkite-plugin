#!/bin/bash
set -euo pipefail

# Check if the build has any failed jobs
function check_build_has_failures() {
  local api_token="$1"

  local org_slug="${BUILDKITE_ORGANIZATION_SLUG:-}"
  local pipeline_slug="${BUILDKITE_PIPELINE_SLUG:-}"
  local build_number="${BUILDKITE_BUILD_NUMBER:-}"

  if [ -z "${api_token}" ]; then
    # No API token, fall back to checking current step only
    return 1
  fi

  if [ -z "${org_slug}" ] || [ -z "${pipeline_slug}" ] || [ -z "${build_number}" ]; then
    echo "Error: Missing required Buildkite environment variables" >&2
    return 1
  fi

  local build_api_url="https://api.buildkite.com/v2/organizations/${org_slug}/pipelines/${pipeline_slug}/builds/${build_number}"
  local build_json="/tmp/buildkite_build_status_${BUILDKITE_BUILD_ID:-unknown}.json"

  local http_code
  http_code=$(curl -s -w "%{http_code}" \
    -H "Authorization: Bearer ${api_token}" \
    -o "${build_json}" \
    "${build_api_url}")

  if [ "${http_code}" -ne 200 ]; then
    echo "Error: Build status API call failed with HTTP ${http_code}" >&2
    rm -f "${build_json}"
    return 1
  fi

  # Check if any job has failed or soft_failed
  local failed_count
  failed_count=$(jq -r '[.jobs[] | select(.type == "script") | select(.state == "failed" or .soft_failed == true)] | length' "${build_json}" 2>/dev/null)

  rm -f "${build_json}"

  if [ "${failed_count}" -gt 0 ]; then
    return 0  # Build has failures
  else
    return 1  # Build has no failures
  fi
}

# Check if build has any failed jobs
has_failed_jobs() {
  local api_key="$1"

  local org="${BUILDKITE_ORGANIZATION_SLUG}"
  local pipeline="${BUILDKITE_PIPELINE_SLUG}"
  local build="${BUILDKITE_BUILD_NUMBER}"

  local url="https://api.buildkite.com/v2/organizations/${org}/pipelines/${pipeline}/builds/${build}"
  local response="/tmp/build_status_${BUILDKITE_BUILD_ID}.json"

  curl -sf \
    -H "Authorization: Bearer ${api_key}" \
    "${url}" > "${response}" || return 1

  local failed_count
  failed_count=$(jq '[.jobs[] | select(.type == "script" and (.state == "failed" or .soft_failed == true))] | length' "${response}")

  rm -f "${response}"

  [ "${failed_count}" -gt 0 ]
}

# Get logs for all failed jobs
get_failed_job_logs() {
  local api_key="$1"

  local org="${BUILDKITE_ORGANIZATION_SLUG}"
  local pipeline="${BUILDKITE_PIPELINE_SLUG}"
  local build="${BUILDKITE_BUILD_NUMBER}"

  local build_url="https://api.buildkite.com/v2/organizations/${org}/pipelines/${pipeline}/builds/${build}"
  local build_json="/tmp/build_${BUILDKITE_BUILD_ID}.json"
  local log_file="/tmp/failed_logs_${BUILDKITE_BUILD_ID}.txt"

  # Get build details
  curl -sf \
    -H "Authorization: Bearer ${api_key}" \
    "${build_url}" > "${build_json}" || {
      echo "Failed to fetch build details" >&2
      return 1
    }

  # Extract failed job IDs and names
  jq -r '.jobs[] | select(.type == "script" and (.state == "failed" or .soft_failed == true)) | "\(.id)|\(.name)"' \
    "${build_json}" > "/tmp/failed_jobs_${BUILDKITE_BUILD_ID}.txt"

  > "${log_file}"

  # Fetch logs for each failed job
  while IFS='|' read -r job_id job_name; do
    echo "=== Failed Job: ${job_name} ===" >> "${log_file}"
    echo "" >> "${log_file}"

    local log_url="https://api.buildkite.com/v2/organizations/${org}/pipelines/${pipeline}/builds/${build}/jobs/${job_id}/log"

    if curl -sf -H "Authorization: Bearer ${api_key}" "${log_url}" >> "${log_file}"; then
      echo "" >> "${log_file}"
      echo "" >> "${log_file}"
    else
      echo "[Could not fetch logs for this job]" >> "${log_file}"
      echo "" >> "${log_file}"
    fi
  done < "/tmp/failed_jobs_${BUILDKITE_BUILD_ID}.txt"

  # Cleanup
  rm -f "${build_json}" "/tmp/failed_jobs_${BUILDKITE_BUILD_ID}.txt"

  echo "${log_file}"
}
