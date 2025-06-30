# Intercom-Asana Webhook Integration

A Ruby Sinatra webhook server that automatically moves Asana tasks when Intercom conversations receive replies, streamlining customer support workflow management.

## 🔧 How It Works

1. **Webhook Reception**: Receives Intercom webhook notifications when conversations are updated
2. **Email Filtering**: Skips processing for excluded email addresses (internal team members)
3. **Task Discovery**: Searches Asana project tasks for matching Intercom conversation URLs in attachments
4. **Task Movement**: Automatically moves the corresponding Asana task to a designated section

## 🚀 Quick Start

### Prerequisites

- Ruby 2.7+
- Bundler
- Asana account with API access
- Intercom account with webhook capabilities

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd intercom-webhooks-ruby
```

2. Install dependencies:
```bash
bundle install
```

3. Set up environment variables (create a `.env` file):
```bash
ASANA_ACCESS_TOKEN=your_asana_token_here
ASANA_PROJECT_GID=your_project_id
ASANA_TARGET_SECTION_GID=your_target_section_id
INTERCOM_ACCESS_TOKEN=your_intercom_token_here
PORT=8080
```

4. Run the server:
```bash
# Development
ruby main.rb

# Production
rackup config.ru
```

## 📡 API Endpoints

### Health Check
```http
GET /health
```
Returns server status and configuration validation.

### Debug Information
```http
GET /debug
```
Shows environment variables and system information (tokens are masked).

### Webhook Endpoint
```http
POST /intercom-webhook
```
Main endpoint that processes Intercom webhook payloads.

### Root
```http
GET /
```
API documentation and available endpoints.

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `ASANA_ACCESS_TOKEN` | Asana Personal Access Token | ✅ |
| `ASANA_PROJECT_GID` | Target Asana project ID | ✅ |
| `ASANA_TARGET_SECTION_GID` | Section ID to move tasks to | ✅ |
| `INTERCOM_ACCESS_TOKEN` | Intercom API token | ⚠️ |
| `PORT` | Server port (default: 8080) | ❌ |

### Email Exclusions

The following email addresses are excluded from triggering task movements:
- Internal team members (`@sebestech.com` domain)
- Support and compliance addresses

To modify the exclusion list, update the `EXCLUDED_EMAILS` constant in `main.rb`.

## 🔍 How to Get Required IDs

### Asana Project GID
1. Open your Asana project in a web browser
2. Copy the number from the URL: `https://app.asana.com/0/{PROJECT_GID}/list`

### Asana Section GID
1. Navigate to the target section in your project
2. Use the Asana API or browser developer tools to find the section ID

### Asana Access Token
1. Go to Asana Developer Console
2. Create a Personal Access Token
3. Copy the generated token

## 📋 Webhook Setup

Configure your Intercom webhook to point to:
```
https://your-domain.com/intercom-webhook
```

Ensure the webhook includes conversation update events.

## 🛠️ Development

### Project Structure

```
├── main.rb              # Main Sinatra application
├── asana_client.rb      # Asana API client wrapper
├── config.ru           # Rack configuration
├── Gemfile             # Ruby dependencies
└── test.json           # Sample webhook payload
```

### Key Components

- **AsanaClient**: Handles all Asana API interactions
- **Webhook Handler**: Processes Intercom payloads and orchestrates task movements
- **Email Filtering**: Prevents internal replies from triggering task moves

### Testing

Use the health and debug endpoints to verify your configuration:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/debug
```

## 📝 Response Formats

### Success Response
```json
{
  "status": "success",
  "message": "Task moved to target section",
  "conversation_id": "123456789",
  "task": {
    "gid": "task_id",
    "name": "Task Name",
    "conversation_url": "https://..."
  }
}
```

### Error Responses
- `400`: Invalid JSON or missing conversation ID
- `404`: Task not found for conversation
- `500`: Asana client not configured or task movement failed

## 🔒 Security Notes

- All API tokens are masked in debug output
- HTTPS is recommended for production deployments
- Webhook payloads should be validated in production

## 📊 Monitoring

The application provides comprehensive logging with emoji indicators:
- ✅ Success operations
- ❌ Errors and failures
- ⚠️ Warnings and skipped operations

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.