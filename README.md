# Claude Summarize Buildkite Plugin

A minimal Buildkite plugin that makes simple calls to Claude via the Buildkite Agent API.

## Usage

Add the plugin to your pipeline step:

```yml
steps:
  - command: echo "Hello World"
    plugins:
      - jfhinchcliffe/claude-summarize#main:
          prompt: "Write a short ballad about a man and his frog 🐸"
```

## Configuration

### `prompt` (required, string)

The prompt to send to Claude.

## Requirements

- Buildkite Agent with Claude API access configured
- `curl` command available

## How it works

The plugin makes a POST request to `http://agent.buildkite.localhost/v3/ai/claude/v1/messages` using the Buildkite Agent Access Token for authentication.

## Example

```yml
steps:
  - command: "npm test"
    plugins:
      - jfhinchcliffe/claude-simple#main:
          prompt: "Analyze the CI/CD pipeline performance"
```

The Claude response will be displayed in your build logs.
