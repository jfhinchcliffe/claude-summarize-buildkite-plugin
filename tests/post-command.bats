#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # Common test variables
  export BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY='sk-ant-test-key'
  export BUILDKITE_COMMAND_EXIT_STATUS='1'  # Simulate failure for most tests
  export BUILDKITE_BUILD_ID='test-build-123'
  export BUILDKITE_JOB_ID='test-job-456'
  export BUILDKITE_PIPELINE_SLUG='test-pipeline'
  export BUILDKITE_BUILD_NUMBER='42'
  export BUILDKITE_BRANCH='main'
  export BUILDKITE_COMMIT='abc123'
  export BUILDKITE_LABEL='Test Job'
  export BUILDKITE_BUILD_URL='https://buildkite.com/test/test-pipeline/builds/42'
  
  # Pre-create the mock response file that our curl stub will reference
  mkdir -p /tmp
  printf '{"content":[{"text":"## Root Cause Analysis\nMock analysis from Claude\n\n## Suggested Fixes\n1. Check your configuration\n2. Verify dependencies"}]}' > "/tmp/claude_response_${BUILDKITE_BUILD_ID}.json"
  
  # Mock tools with simpler stubs
  stub curl \
    "* : echo '200'"
  stub jq \
    "* : echo 'Mock analysis from Claude'"
  stub buildkite-agent \
    "annotate * : echo 'Annotation created'" \
    "step * : echo 'No logs available'"
}

teardown() {
  # Clean up mock files
  rm -f "/tmp/claude_response_${BUILDKITE_BUILD_ID:-test-build-123}.json"
  rm -f "/tmp/buildkite_logs_${BUILDKITE_BUILD_ID:-test-build-123}.txt"
  
  # Only unstub if they were actually stubbed
  if command -v curl >/dev/null 2>&1 && curl --help 2>&1 | grep -q "stub"; then
    unstub curl
  fi
  if command -v jq >/dev/null 2>&1 && jq --help 2>&1 | grep -q "stub"; then
    unstub jq
  fi
  if command -v buildkite-agent >/dev/null 2>&1 && buildkite-agent --help 2>&1 | grep -q "stub"; then
    unstub buildkite-agent
  fi
}

@test "Missing API key fails" {
  unset BUILDKITE_PLUGIN_CLAUDE_CODE_API_KEY

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial 'api_key is required'
}

@test "Plugin runs with minimal configuration on failure" {
  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Claude Code Plugin (Post-Command)'
  assert_output --partial 'Model: claude-3-5-sonnet-20241022'
  assert_output --partial 'Trigger: on-failure'
  assert_output --partial 'Command completed with exit status: 1'
  assert_output --partial 'Triggering Claude analysis'
}

@test "Plugin skips analysis on success with on-failure trigger" {
  export BUILDKITE_COMMAND_EXIT_STATUS='0'

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Claude Code Plugin (Post-Command)'
  assert_output --partial 'Command completed with exit status: 0'
  assert_output --partial 'Skipping Claude analysis (trigger: on-failure, exit status: 0)'
  refute_output --partial 'Triggering Claude analysis'
}

@test "Plugin runs on success with always trigger" {
  export BUILDKITE_PLUGIN_CLAUDE_CODE_TRIGGER='always'
  export BUILDKITE_COMMAND_EXIT_STATUS='0'

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Trigger: always'
  assert_output --partial 'Command completed with exit status: 0'
  assert_output --partial 'Triggering Claude analysis'
}

@test "Plugin respects manual trigger with environment variable" {
  export BUILDKITE_PLUGIN_CLAUDE_CODE_TRIGGER='manual'
  export CLAUDE_ANALYZE='true'

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Trigger: manual'
  assert_output --partial 'Triggering Claude analysis'
}

@test "Plugin skips manual trigger without environment variable" {
  export BUILDKITE_PLUGIN_CLAUDE_CODE_TRIGGER='manual'
  export BUILDKITE_COMMAND_EXIT_STATUS='1'

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Trigger: manual'
  assert_output --partial 'Skipping Claude analysis'
  refute_output --partial 'Triggering Claude analysis'
}

@test "Plugin respects manual trigger with commit message" {
  export BUILDKITE_PLUGIN_CLAUDE_CODE_TRIGGER='manual'
  export BUILDKITE_MESSAGE='Fix bug [claude-analyze] in authentication'

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Trigger: manual'
  assert_output --partial 'Triggering Claude analysis'
}

@test "Plugin uses custom model" {
  export BUILDKITE_PLUGIN_CLAUDE_CODE_MODEL='claude-3-opus-20240229'

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Model: claude-3-opus-20240229'
}

@test "Plugin uses custom max log lines" {
  export BUILDKITE_PLUGIN_CLAUDE_CODE_MAX_LOG_LINES='500'

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Max log lines: 500'
}

@test "Plugin handles custom prompt" {
  export BUILDKITE_PLUGIN_CLAUDE_CODE_CUSTOM_PROMPT='Focus on Node.js issues'

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Triggering Claude analysis'
}

@test "Plugin can disable annotations" {
  export BUILDKITE_PLUGIN_CLAUDE_CODE_ANNOTATE='false'

  run "$PWD"/hooks/post-command

  assert_success
  # Should still output to logs but not create annotations
  assert_output --partial 'Claude Analysis Results'
}

@test "Plugin handles API failure gracefully" {
  # Override curl to simulate API failure
  teardown  # Clean up existing stubs
  stub curl \
    "* : echo '500'"
  stub jq \
    "* : echo 'Mock response'"
  stub buildkite-agent \
    "annotate * : echo 'Annotation created'" \
    "step * : echo 'No logs available'"

  run "$PWD"/hooks/post-command

  assert_success  # Post-command hooks don't fail the build
  assert_output --partial 'Claude analysis failed'
}
