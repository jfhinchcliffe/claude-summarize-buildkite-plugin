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

# Create a basic log with build information
function create_fallback_log() {
  local log_file="$1"

  {
    echo "Build Information:"
    echo "Pipeline: ${BUILDKITE_PIPELINE_SLUG:-Unknown}"
    echo "Build: #${BUILDKITE_BUILD_NUMBER:-Unknown}"
    echo "Job: ${BUILDKITE_LABEL:-Unknown}"
    echo "Branch: ${BUILDKITE_BRANCH:-Unknown}"
    echo "Commit: ${BUILDKITE_COMMIT:-Unknown}"
    echo "Exit Status: ${BUILDKITE_COMMAND_EXIT_STATUS:-Unknown}"
    echo "Command: ${BUILDKITE_COMMAND:-Unknown}"
  } > "${log_file}"

  return 0
}

# Fetch logs from Buildkite API for all jobs in the build
function fetch_logs_from_api() {
  local api_token="$1"
  local log_file="$2"

  local org_slug="${BUILDKITE_ORGANIZATION_SLUG:-}"
  local pipeline_slug="${BUILDKITE_PIPELINE_SLUG:-}"
  local build_number="${BUILDKITE_BUILD_NUMBER:-}"

  if [ -z "${org_slug}" ] || [ -z "${pipeline_slug}" ] || [ -z "${build_number}" ]; then
    echo "Error: Missing required Buildkite environment variables" >&2
    return 1
  fi

  # First, get the build details to list all jobs
  local build_api_url="https://api.buildkite.com/v2/organizations/${org_slug}/pipelines/${pipeline_slug}/builds/${build_number}"
  local build_json="/tmp/buildkite_build_${BUILDKITE_BUILD_ID:-unknown}.json"

  local http_code
  http_code=$(curl -s -w "%{http_code}" \
    -H "Authorization: Bearer ${api_token}" \
    -o "${build_json}" \
    "${build_api_url}")

  if [ "${http_code}" -ne 200 ]; then
    echo "Error: Build API call failed with HTTP ${http_code}" >&2
    rm -f "${build_json}"
    return 1
  fi

  # Extract job IDs from the build
  local job_ids
  job_ids=$(jq -r '.jobs[] | select(.type == "script") | .id' "${build_json}" 2>/dev/null)

  if [ -z "${job_ids}" ]; then
    echo "Error: No jobs found in build" >&2
    rm -f "${build_json}"
    return 1
  fi

  # Clear the log file
  > "${log_file}"

  # Fetch logs for each job
  local job_count=0
  while IFS= read -r job_id; do
    if [ -z "${job_id}" ]; then
      continue
    fi

    ((job_count++))

    # Get job details for the label
    local job_label
    job_label=$(jq -r --arg job_id "${job_id}" '.jobs[] | select(.id == $job_id) | .name // .id' "${build_json}" 2>/dev/null)

    echo "=== Job: ${job_label} (${job_id}) ===" >> "${log_file}"

    local job_log_url="https://api.buildkite.com/v2/organizations/${org_slug}/pipelines/${pipeline_slug}/builds/${build_number}/jobs/${job_id}/log"
    local temp_log="/tmp/buildkite_job_log_${job_id}.txt"

    http_code=$(curl -s -w "%{http_code}" \
      -H "Authorization: Bearer ${api_token}" \
      -o "${temp_log}" \
      "${job_log_url}")

    if [ "${http_code}" -eq 200 ] && [ -s "${temp_log}" ]; then
      cat "${temp_log}" >> "${log_file}"
      echo "" >> "${log_file}"
    else
      echo "[No logs available for this job]" >> "${log_file}"
      echo "" >> "${log_file}"
    fi

    rm -f "${temp_log}"
  done <<< "${job_ids}"

  rm -f "${build_json}"

  if [ "${job_count}" -eq 0 ]; then
    echo "Error: No jobs processed" >&2
    return 1
  fi

  echo "Fetched logs from ${job_count} job(s)" >&2

  # Check if we got actual log content
  if [ ! -s "${log_file}" ]; then
    echo "Error: No log content received from API" >&2
    return 1
  fi

  return 0
}

# Main function to get logs
function fetch_build_logs() {
  local api_token="$1"
  local max_lines="${2:-1000}"
  local analysis_level="${3:-step}"

  local build_id="${BUILDKITE_BUILD_ID:-unknown}"
  local log_file="/tmp/buildkite_logs_${build_id}.txt"

  if ! touch "${log_file}" 2>/dev/null; then
    return 1
  fi

  # Try to fetch logs from API if token is provided
  if [ -n "${api_token}" ]; then
    if fetch_logs_from_api "${api_token}" "${log_file}"; then
      # Limit the number of lines if requested
      if [ "${max_lines}" -gt 0 ]; then
        local temp_file="${log_file}.tmp"
        tail -n "${max_lines}" "${log_file}" > "${temp_file}"
        mv "${temp_file}" "${log_file}"
      fi
      echo "${log_file}"
      return 0
    else
      echo "Warning: Failed to fetch logs from API, using fallback" >&2
    fi
  fi

  # Fallback - create a basic log with available information
  if create_fallback_log "${log_file}"; then
    echo "${log_file}"
    return 0
  else
    return 1
  fi
}
