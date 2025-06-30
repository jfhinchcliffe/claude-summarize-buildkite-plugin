# Claude Code Buildkite Plugin [![Build status](https://badge.buildkite.com/741da64ce676981eccb96fd67290a2695da07921cdc111b03a.svg)](https://buildkite.com/no-assembly/claude-code-plugin)

AI-powered build analysis and error diagnosis using Claude. This plugin automatically analyzes build failures, provides root cause analysis, and suggests actionable fixes through Buildkite annotations.

## Features

- 🤖 **Intelligent Build Analysis**: Claude analyzes build logs to identify root causes of failures
- 📋 **Buildkite Annotations**: Creates rich annotations with analysis results and suggested fixes
- ⚡ **Smart Triggering**: Configurable triggers (on-failure, always, manual)
- 🔧 **Actionable Insights**: Provides specific steps to resolve issues and prevent future failures
- 🎯 **Context-Aware**: Understands build context including branch, commit, and job information

## Requirements

- **curl**: For API requests
- **jq**: For JSON processing
- **Anthropic API Key**: From [console.anthropic.com](https://console.anthropic.com)

## Quick Start

1. Get your Anthropic API key from [console.anthropic.com](https://console.anthropic.com)
2. Add it to your Buildkite environment variables as `ANTHROPIC_API_KEY`
3. Add the plugin to your pipeline using one of these approaches:

```yaml
steps:
  # Option 1: Using environment variable
  - label: "🧪 Run tests"
    command: "npm test"
    plugins:
      - mcncl/claude-code#v1.0.0:
          api_key: "${ANTHROPIC_API_KEY}"
          
  # Option 2: Using Buildkite secrets (recommended)
  - label: "🧪 More tests"
    command: "npm test"
    plugins:
      - mcncl/claude-code#v1.0.0:
          secret_name: "ANTHROPIC_API_KEY"
```

## Configuration Options

### Required (one of the following)

#### `api_key` (string)

Your Anthropic API key for accessing Claude. Store this securely in your Buildkite environment variables.

#### `secret_name` (string)

Name of a Buildkite secret containing your Anthropic API key. The plugin will automatically fetch the secret using `buildkite-agent secret get`.

```yaml
# Option 1: Using environment variable
plugins:
  - mcncl/claude-code#v1.0.0:
      api_key: "${ANTHROPIC_API_KEY}"

# Option 2: Using Buildkite secrets
plugins:
  - mcncl/claude-code#v1.0.0:
      secret_name: "ANTHROPIC_API_KEY"
```

### Optional

#### `model` (string)

Claude model to use for analysis. Default: `claude-3-5-sonnet-20241022`

```yaml
plugins:
  - mcncl/claude-code#v1.0.0:
      api_key: "${ANTHROPIC_API_KEY}"
      model: "claude-3-5-sonnet-20241022"
```

#### `trigger` (string)

When to trigger Claude analysis. Options: `on-failure`, `always`, `manual`. Default: `on-failure`

- `on-failure`: Only analyze when the build step fails
- `always`: Analyze every build (success or failure)
- `manual`: Only when `CLAUDE_ANALYZE=true` environment variable is set or commit message contains `[claude-analyze]`

```yaml
plugins:
  - mcncl/claude-code#v1.0.0:
      api_key: "${ANTHROPIC_API_KEY}"
      trigger: "always"
```

#### `max_log_lines` (integer)

Maximum number of log lines to send to Claude for analysis. Default: `1000`

```yaml
plugins:
  - mcncl/claude-code#v1.0.0:
      api_key: "${ANTHROPIC_API_KEY}"
      max_log_lines: 500
```

#### `custom_prompt` (string)

Additional context or instructions to include in the analysis prompt.

```yaml
plugins:
  - mcncl/claude-code#v1.0.0:
      api_key: "${ANTHROPIC_API_KEY}"
      custom_prompt: "This is a Node.js project using Jest for testing. Pay special attention to dependency issues."
```

#### `timeout` (integer)

Timeout in seconds for Claude API requests. Default: `60`

```yaml
plugins:
  - mcncl/claude-code#v1.0.0:
      api_key: "${ANTHROPIC_API_KEY}"
      timeout: 120
```

#### `annotate` (boolean)

Whether to create Buildkite annotations with the analysis results. Default: `true`

```yaml
plugins:
  - mcncl/claude-code#v1.0.0:
      api_key: "${ANTHROPIC_API_KEY}"
      annotate: false  # Only output to build logs
```

## Examples

### Basic Usage - Analyze Failed Tests

```yaml
steps:
  - label: "🧪 Run tests"
    command: "npm test"
    plugins:
      - mcncl/claude-code#v1.0.0:
          api_key: "${ANTHROPIC_API_KEY}"
```

When tests fail, Claude will analyze the output and create an annotation with:
- Root cause analysis
- Key error explanations
- Suggested fixes
- Prevention strategies

### Always Analyze Builds

```yaml
steps:
  - label: "🏗️ Build application"
    command: "npm run build"
    plugins:
      - mcncl/claude-code#v1.0.0:
          api_key: "${ANTHROPIC_API_KEY}"
          trigger: "always"
          custom_prompt: "Focus on build performance and optimization opportunities"
```

### Manual Analysis with Custom Context

```yaml
steps:
  - label: "🚀 Deploy to staging"
    command: "./deploy.sh staging"
    env:
      CLAUDE_ANALYZE: "true"  # Trigger manual analysis
    plugins:
      - mcncl/claude-code#v1.0.0:
          api_key: "${ANTHROPIC_API_KEY}"
          trigger: "manual"
          custom_prompt: "This is a deployment script. Focus on infrastructure and configuration issues."
          max_log_lines: 2000
```

### Multiple Steps with Different Configurations

```yaml
steps:
  - label: "🔍 Lint code"
    command: "npm run lint"
    plugins:
      - mcncl/claude-code#v1.0.0:
          api_key: "${ANTHROPIC_API_KEY}"
          custom_prompt: "Focus on code quality and style issues"

  - label: "🧪 Run tests"
    command: "npm test"
    plugins:
      - mcncl/claude-code#v1.0.0:
          api_key: "${ANTHROPIC_API_KEY}"
          custom_prompt: "Focus on test failures and coverage issues"

  - label: "🏗️ Build production"
    command: "npm run build:prod"
    plugins:
      - mcncl/claude-code#v1.0.0:
          api_key: "${ANTHROPIC_API_KEY}"
          trigger: "always"
          custom_prompt: "Focus on build optimization and bundle analysis"
```

## Compatibility

| Elastic Stack | Agent Stack K8s | Hosted (Mac) | Hosted (Linux) | Notes |
| :-----------: | :-------------: | :----------: | :------------: | :---- |
| 🧪 | 🧪 | 🧪 | 🧪 |   |

- 🧪 Testing compatibility

## ⚒ Developing

Run tests with

```bash
docker compose run --rm tests
```

## 👩‍💻 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

Please follow the existing code style and include tests for any new features.

## 📜 License

The package is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
