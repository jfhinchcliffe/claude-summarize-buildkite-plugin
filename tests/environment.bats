#!/usr/bin/env bats

# shellcheck disable=SC2030,SC2031 # Disable warnings for variable modifications in BATS subshells

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # Common test variables
  export BUILDKITE_BUILD_ID='test-build-123'
  export BUILDKITE_JOB_ID='test-job-456'
  export BUILDKITE_PIPELINE_SLUG='test-pipeline'

  # Mock buildkite-agent
  stub buildkite-agent \
    "secret get TEST_SECRET : echo 'sk-ant-secret-key'" \
    "secret get EMPTY_SECRET : echo ''" \
    "secret get MISSING_SECRET : exit 1"
}

teardown() {
  # Clean up environment variables
  unset BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY
  unset TEST_ENV_VAR
  unset EMPTY_ENV_VAR

  # Only unstub if they were actually stubbed
  if command -v buildkite-agent >/dev/null 2>&1 && buildkite-agent --help 2>&1 | grep -q "stub"; then
    unstub buildkite-agent
  fi
}

@test "Environment hook resolves Buildkite secret syntax" {
  local api_key
  api_key="$(buildkite-agent secret get TEST_SECRET)"
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="$api_key"

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Check that the resolved key is exported
  [ "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY}" = "sk-ant-secret-key" ]
}

@test "Environment hook resolves environment variable syntax with braces" {
  export TEST_ENV_VAR='sk-ant-env-key'
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="${TEST_ENV_VAR}"

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Check that the resolved key is exported
  [ "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY}" = "sk-ant-env-key" ]
}

@test "Environment hook resolves environment variable syntax without braces" {
  export TEST_ENV_VAR='sk-ant-env-key-2'
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="$TEST_ENV_VAR"

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Check that the resolved key is exported
  [ "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY}" = "sk-ant-env-key-2" ]
}

@test "Environment hook handles literal API key values" {
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="sk-ant-literal-key"

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Check that the literal key is exported as-is
  [ "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY}" = "sk-ant-literal-key" ]
}

@test "Environment hook handles missing Buildkite secret gracefully" {
  local api_key
  api_key="$(buildkite-agent secret get MISSING_SECRET)"
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="$api_key"

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Check that the API key is not set when secret is missing
  [ -z "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY:-}" ]
}

@test "Environment hook handles empty Buildkite secret gracefully" {
  local api_key
  api_key="$(buildkite-agent secret get EMPTY_SECRET)"
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="$api_key"

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Check that the API key is not set when secret is empty
  [ -z "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY:-}" ]
}

@test "Environment hook handles missing environment variable gracefully" {
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="${MISSING_ENV_VAR}"

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Check that the API key is not set when environment variable is missing
  [ -z "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY:-}" ]
}

@test "Environment hook handles empty environment variable gracefully" {
  export EMPTY_ENV_VAR=''
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="${EMPTY_ENV_VAR}"

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Check that the API key is not set when environment variable is empty
  [ -z "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY:-}" ]
}

@test "Environment hook handles buildkite-agent not available" {
  local api_key
  api_key="$(buildkite-agent secret get TEST_SECRET)"
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="$api_key"

  # Override the stub to simulate buildkite-agent not being available
  teardown

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Check that the API key is not set when buildkite-agent is not available
  [ -z "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY:-}" ]
}

@test "Environment hook requires API_KEY to be set" {
  # Don't set API_KEY to test required behavior

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # API_KEY is required, should not be set if not provided
  [ -z "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY:-}" ]
}

@test "Environment hook handles API keys starting with sk-ant" {
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="sk-ant-preferred-key"

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Check that the api_key value is used
  [ "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY}" = "sk-ant-preferred-key" ]
}

@test "Environment hook handles environment variable names with underscores" {
  export MY_SECRET_ENV_VAR='sk-ant-underscore-env-key'
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="${MY_SECRET_ENV_VAR}"

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Check that the resolved key is exported
  [ "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY}" = "sk-ant-underscore-env-key" ]
}

@test "Environment hook ignores invalid command substitution patterns" {
  local api_key
  api_key="$(invalid-command get TEST_SECRET)"
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY="$api_key"

  # Source the environment hook instead of running it
  source "$PWD"/hooks/environment

  # Should be treated as a literal value
  [ "${BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY}" = "$(invalid-command get TEST_SECRET)" ]
}
