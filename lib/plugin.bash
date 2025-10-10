#!/bin/bash
set -euo pipefail

PLUGIN_PREFIX="CLAUDE_SUMMARIZE"

# Reads a single value
function plugin_read_config() {
  local var="BUILDKITE_PLUGIN_${PLUGIN_PREFIX}_${1}"
  local default="${2:-}"
  echo "${!var:-$default}"
}

# Get build logs
function get_build_logs() {
  local max_lines="${1:-1000}"
  local analysis_level="${2:-step}"

  # Call the refactored implementation from logs.bash
  local log_file
  if log_file=$(fetch_build_logs "" "${max_lines}" "${analysis_level}"); then
    echo "${log_file}"
    return 0
  else
    return 1
  fi
}
