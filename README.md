# Claude Summarize Buildkite Plugin

AI-powered build failure analysis using Claude via Buildkite's hosted AI endpoint.

## Features

- Automatically detects failed jobs in a build
- Fetches logs for failed jobs via Buildkite API
- Uses Claude to analyze failures and suggest fixes
- Creates annotated build report with actionable recommendations

## Requirements

- Buildkite Agent with access to hosted Claude endpoint
- Buildkite API token with `read_builds` scope
- `jq` for JSON processing

## Usage

Add this plugin to any step in your pipeline (typically the last step):

```yaml
steps:
  - label: ":hammer: Build"
    command: "make build"

  - label: ":test_tube: Tests"
    command: "make test"

  - label: ":robot_face: AI Analysis"
    command: "echo 'Analyzing build...'"
    plugins:
      - claude-summarize#v2.0.0:
          api_key: "${BUILDKITE_API_TOKEN}"
```

The plugin will:
1. Check if any jobs in the build have failed
2. Fetch logs for failed jobs
3. Send logs to Claude for analysis
4. Create an annotation with root cause and fix recommendations

## Configuration

### `api_key` (required)

Buildkite API token with `read_builds` scope.

Create a token at: `https://buildkite.com/user/api-access-tokens`

Can be provided via:
- Plugin configuration: `api_key: "${BUILDKITE_API_TOKEN}"`
- Environment variable: `BUILDKITE_API_TOKEN`

### `custom_prompt` (optional)

Additional context to help Claude analyze the failure.

```yaml
plugins:
  - claude-summarize#v2.0.0:
      api_key: "${BUILDKITE_API_TOKEN}"
      custom_prompt: "This is a Ruby on Rails app with PostgreSQL database"
```

## Examples

### Basic Usage

```yaml
steps:
  - label: "Tests"
    command: "npm test"

  - label: "AI Analysis"
    command: "echo 'Running analysis...'"
    plugins:
      - claude-summarize#v2.0.0:
          api_key: "${BUILDKITE_API_TOKEN}"
```

### With Custom Context

```yaml
steps:
  - label: "Deploy"
    command: "./deploy.sh"

  - label: "AI Analysis"
    command: "echo 'Running analysis...'"
    plugins:
      - claude-summarize#v2.0.0:
          api_key: "${BUILDKITE_API_TOKEN}"
          custom_prompt: "This is a Kubernetes deployment. Focus on infrastructure and networking issues."
```

### Always Run Analysis (Even on Failure)

```yaml
steps:
  - label: "Tests"
    command: "npm test"

  - label: "AI Analysis"
    command: "echo 'Running analysis...'"
    depends_on:
      - step: "Tests"
        allow_failure: true
    plugins:
      - claude-summarize#v2.0.0:
          api_key: "${BUILDKITE_API_TOKEN}"
```

### With Soft Fail Steps

```yaml
steps:
  - label: "Linting"
    command: "npm run lint"
    soft_fail: true

  - label: "Tests"
    command: "npm test"

  - label: "AI Analysis"
    command: "echo 'Running analysis...'"
    plugins:
      - claude-summarize#v2.0.0:
          api_key: "${BUILDKITE_API_TOKEN}"
          custom_prompt: "Note: Linting failures are soft-fails and don't block the build"
```

## How It Works

1. Plugin runs in the `post-command` hook
2. Calls Buildkite API to check build status
3. If failures detected:
   - Fetches logs for all failed jobs
   - Sends logs + custom prompt to Claude via Buildkite's hosted AI endpoint
   - Creates an error annotation with analysis
4. If no failures, skips analysis

## Output

When failures are detected, Claude creates an annotation like:

```
## Build Failure Analysis

**Build:** [my-pipeline #123](https://buildkite.com/...)

### Root Causes:
1. Test failure in UserAuthenticationTest
   - Assertion error: expected 200, got 401
   - Issue: JWT token expired in test fixtures

2. Build step failed
   - Missing dependency: libssl-dev

### Recommended Fixes:
1. Update test fixtures with fresh JWT tokens
2. Add libssl-dev to Dockerfile apt-get install
```

## License

MIT
