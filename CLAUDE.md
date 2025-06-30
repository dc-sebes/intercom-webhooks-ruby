# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture

This is a Ruby Sinatra webhook server that integrates Intercom and Asana:

- **main.rb**: Main application with Sinatra routes and webhook handling logic
- **asana_client.rb**: AsanaClient class that wraps Asana API interactions
- **config.ru**: Rack configuration for deployment

### Core Flow
1. Receives Intercom webhooks at `/intercom-webhook`
2. Extracts conversation ID and author email from payload
3. Skips processing if author email is in EXCLUDED_EMAILS list
4. Uses AsanaClient to find Asana task by conversation ID (searches task attachments for Intercom URLs)
5. Moves the found task to a target section in Asana

## Development Commands

### Setup
```bash
bundle install
```

### Run Server
```bash
# Development
ruby main.rb

# Production (via Rack)
rackup config.ru
```

### Testing
```bash
# Run all tests
rake test
# or
bundle exec rake test

# Run specific test categories
rake test_unit          # AsanaClient unit tests only
rake test_integration   # API endpoints and integration tests

# Run individual test files
ruby -Itest test/asana_client_test.rb
ruby -Itest test/endpoints_test.rb
ruby -Itest test/integration_test.rb
```

### Environment Variables Required
- `ASANA_ACCESS_TOKEN`: Asana API token
- `ASANA_PROJECT_GID`: Asana project ID  
- `ASANA_TARGET_SECTION_GID`: Target section ID for moving tasks
- `INTERCOM_ACCESS_TOKEN`: Intercom API token (referenced but not used yet)
- `PORT`: Server port (defaults to 8080)

### Testing Endpoints
- `GET /health` - Health check with environment status
- `GET /debug` - Environment variables and configuration info
- `GET /` - API documentation
- `POST /intercom-webhook` - Main webhook endpoint

## Key Implementation Details

- Email exclusion list in EXCLUDED_EMAILS constant prevents certain authors from triggering task moves
- AsanaClient searches all project tasks and their attachments to find matching Intercom conversation URLs
- Error handling includes JSON parsing, missing conversation IDs, and Asana API failures
- Logging uses Unicode emoji symbols for visual clarity