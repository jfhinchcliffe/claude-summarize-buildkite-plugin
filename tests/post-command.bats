#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  export BUILDKITE_COMMAND_EXIT_STATUS='1'
  export BUILDKITE_BUILD_ID='test-build-123'
  export BUILDKITE_JOB_ID='test-job-456'
  export BUILDKITE_PIPELINE_SLUG='test-pipeline'
  export BUILDKITE_BUILD_NUMBER='42'
  export BUILDKITE_BRANCH='main'
  export BUILDKITE_COMMIT='abc123'
  export BUILDKITE_LABEL='Test Job'
  export BUILDKITE_BUILD_URL='https://buildkite.com/test/builds/42'
  export BUILDKITE_AGENT_ACCESS_TOKEN='test-token'

  mkdir -p /tmp
  printf '{"content":[{"text":"Root cause: test failure"}]}' > "/tmp/claude_response_${BUILDKITE_BUILD_ID}.json"

  stub curl \
    "* : echo '200'"

  stub jq \
    "-n * : echo '{}'" \
    "-r * : echo 'Root cause: test failure'"

  stub buildkite-agent \
    "annotate * : echo 'Annotation created'"
}

teardown() {
  rm -f "/tmp/claude_response_${BUILDKITE_BUILD_ID:-test-build-123}.json"
  rm -f "/tmp/buildkite_logs_${BUILDKITE_BUILD_ID:-test-build-123}.txt"
  rm -f "/tmp/claude_annotation_${BUILDKITE_BUILD_ID:-test-build-123}.md"
  rm -f "/tmp/claude_prompt_${BUILDKITE_BUILD_ID:-test-build-123}.txt"
  rm -f "/tmp/claude_payload_${BUILDKITE_BUILD_ID:-test-build-123}.json"

  unstub curl || true
  unstub jq || true
  unstub buildkite-agent || true
}

@test "Missing agent token fails" {
  unset BUILDKITE_AGENT_ACCESS_TOKEN

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial 'BUILDKITE_AGENT_ACCESS_TOKEN not available'
}

@test "Plugin runs on failure" {
  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Analyzing build failure'
}

@test "Plugin skips on success" {
  export BUILDKITE_COMMAND_EXIT_STATUS='0'

  run "$PWD"/hooks/post-command

  assert_success
  refute_output --partial 'Analyzing build failure'
}

@test "Plugin handles custom prompt" {
  export BUILDKITE_PLUGIN_CLAUDE_SUMMARIZE_CUSTOM_PROMPT='Focus on Docker issues'

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Analyzing build failure'
}
