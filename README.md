# Claude Summarize Buildkite Plugin

AI-powered build failure analysis using Claude via Buildkite's hosted endpoint.

## Features

- Automatic root cause analysis of build failures and soft-fails
- Always creates an annotation (success or analysis)
- Uses Buildkite's hosted Claude endpoint (no API key management required)
- Fetches actual build logs via Buildkite API for detailed analysis
- Minimal configuration

## Requirements

- Buildkite Agent with access to hosted Claude endpoint
- `jq` for JSON processing
- Buildkite API token with `read_builds` scope (for log fetching)

## Usage

Add the plugin to your pipeline:

```yaml
steps:
  - label: "Run tests"
    command: "npm test"
    plugins:
      - claude-summarize#v2.0.0:
          api_token: "${BUILDKITE_API_TOKEN}"
```

## Behavior

The plugin runs after every step and:
- **On success**: Creates a simple success annotation
- **On failure or soft-fail**: Fetches logs from **all jobs in the build** via the Buildkite API and analyzes them, creating a detailed error annotation with root cause and fix suggestions

## Configuration

### Optional

#### `api_token` (string)

Buildkite API token with `read_builds` scope. Required to fetch actual build logs from the Buildkite API. If not provided, the plugin will fall back to basic build information only.

You can provide this via:
- Plugin configuration (as shown below)
- Environment variable: `BUILDKITE_API_TOKEN`

**Note:** Create an API token at `https://buildkite.com/user/api-access-tokens` with the `read_builds` scope.

```yaml
steps:
  - label: "Run tests"
    command: "npm test"
    plugins:
      - claude-summarize#v2.0.0:
          api_token: "${BUILDKITE_API_TOKEN}"
```

#### `custom_prompt` (string)

Additional context or instructions to include in the analysis.

```yaml
steps:
  - label: "Deploy"
    command: "./deploy.sh"
    plugins:
      - claude-summarize#v2.0.0:
          api_token: "${BUILDKITE_API_TOKEN}"
          custom_prompt: "This is a deployment script. Focus on infrastructure issues."
```

## How It Works

1. Plugin runs after each command via post-command hook
2. Checks `BUILDKITE_COMMAND_EXIT_STATUS` and `SOFT_FAIL` environment variables
3. On success: Creates simple success annotation
4. On failure/soft-fail: 
   - Fetches the build details from Buildkite API (if API token provided)
   - Retrieves logs from **all jobs** in the build for comprehensive analysis
   - Sends combined logs to Buildkite's hosted Claude endpoint
   - Creates annotation with detailed analysis

## Examples

### Basic Usage

```yaml
steps:
  - label: "Run tests"
    command: "npm test"
    plugins:
      - claude-summarize#v2.0.0:
          api_token: "${BUILDKITE_API_TOKEN}"
```

### With Soft-Fail

```yaml
steps:
  - label: "Run linter"
    command: "npm run lint"
    soft_fail: true
    plugins:
      - claude-summarize#v2.0.0:
          api_token: "${BUILDKITE_API_TOKEN}"
```

### With Custom Prompt

```yaml
steps:
  - label: "Build Docker image"
    command: "docker build ."
    plugins:
      - claude-summarize#v2.0.0:
          api_token: "${BUILDKITE_API_TOKEN}"
          custom_prompt: "Focus on Docker and container issues."
```

## License

MIT
