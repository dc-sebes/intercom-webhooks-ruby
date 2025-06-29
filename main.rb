require 'puma'
require 'sinatra'
require 'json'
require 'dotenv/load'
require_relative './asana_client'

# List of email addresses for which tasks should not be moved in Asana
EXCLUDED_EMAILS = [
  "i.konovalov@sebestech.com",
  "f.veips@sebestech.com",
  "help@sebestech.com",
  "support@sebestech.com",
  "compliance@sebestech.com",
  "k.danyleyko@sebestech.com",
  "n.rozkalns@sebestech.com",
  "a.vaver@sebestech.com",
  "d.ciruks@sebestech.com"
]

def init_asana_client
  if ENV['ASANA_ACCESS_TOKEN']
    begin
      client = AsanaClient.new
      puts "✅ Asana client initialized successfully"
      return client
    rescue => e 
      puts "❌ Error initializing Asana: #{e}"
      nil
    end
  else
    puts "❌ Asana client not initialized - ASANA_ACCESS_TOKEN missing"
    nil
  end
end


def init_intercom_client
  if ENV['INTERCOM_ACCESS_TOKEN']
    puts "✅ Intercom client initialized successfully"
    #IntercomClient.new
  else
    puts "❌ Intercom client not initialized - INTERCOM_ACCESS_TOKEN missing"
    nil
  end
end

ASANA_CLIENT = init_asana_client
INTERCOM_CLIENT = init_intercom_client

# Health check
get '/health' do
  content_type :json
  {
    status: 'healthy',
    asana_client_configured: !!ASANA_CLIENT,
    environment_check: {
      ASANA_ACCESS_TOKEN: !!ENV['ASANA_ACCESS_TOKEN'],
      ASANA_PROJECT_GID: !!ENV['ASANA_PROJECT_GID'],
      ASANA_TARGET_SECTION_GID: !!ENV['ASANA_TARGET_SECTION_GID'],
    }
  }.to_json
end

# Debug endpoint
get '/debug' do
  content_type :json
  {
    environment_variables: {
      ASANA_ACCESS_TOKEN: ENV['ASANA_ACCESS_TOKEN'] ? "***HIDDEN***" : "NOT SET",
      ASANA_PROJECT_GID: ENV['ASANA_PROJECT_GID'] || 'NOT SET',
      ASANA_TARGET_SECTION_GID: ENV['ASANA_TARGET_SECTION_GID'] || 'NOT SET',
      PORT: ENV['PORT'] || 'NOT SET',
      DEBUG: ENV['DEBUG'] || 'NOT SET',
      INTERCOM_ACCESS_TOKEN: ENV['INTERCOM_ACCESS_TOKEN'] || 'NOT SET'
    },
    asana_client_initialized: !!ASANA_CLIENT,
    ruby_version: RUBY_VERSION
  }.to_json
end

# Root
get '/' do
  content_type :json
  {
    message: 'Intercom Webhook Handler',
    endpoints: {
      webhook: '/intercom-webhook',
      health: '/health',
      debug: '/debug'
    }
  }.to_json
end

### Main code ###

def extract_current_reply_author_email(payload)
  item = payload.dig('data', 'item') || {}
  parts = item.dig('conversation_parts', 'conversation_parts') || []
  return nil if parts.empty?

  latest_part = parts.last
  author = latest_part['author'] || {}
  author['email']
end

def excluded_author_email?(payload)
  email = extract_current_reply_author_email(payload)
  return false unless email

  EXCLUDED_EMAILS.map(&:downcase).include?(email.downcase)
end

post '/intercom-webhook' do
  content_type :json
  begin
    payload = JSON.parse(request.body.read)
  rescue JSON::ParserError => e
    puts "\u274c Invalid JSON payload: #{e}"
    status 400
    return { status: 'error', message: 'Invalid JSON' }.to_json
  end

  puts "Webhook received: #{payload.inspect}"

  if excluded_author_email?(payload)
    puts "\u274c Author email is in the exclusion list - no action"
    status 200
    return {
      status: 'skipped',
      reason: 'Author email in exclusion list'
    }.to_json
  end

  conversation_id = payload.dig('data', 'item', 'id')

  unless conversation_id
    puts "\u274c Conversation ID not found in payload"
    status 400
    return { status: 'error', message: 'Conversation ID missing' }.to_json
  end

  unless ASANA_CLIENT
    puts "\u274c Asana client not initialized"
    status 500
    return { status: 'error', message: 'Asana client not configured' }.to_json
  end

  task = ASANA_CLIENT.find_task_by_conversation_id(conversation_id)

  unless task
    puts "\u274c Task not found for conversation #{conversation_id}"
    status 404
    return {
      status: 'error',
      message: 'Task not found for conversation',
      conversation_id: conversation_id
    }.to_json
  end

  moved = ASANA_CLIENT.move_task_to_section(task[:gid])

  if moved
    puts "\u2705 Moved task #{task[:gid]} for conversation #{conversation_id}"
    {
      status: 'success',
      message: 'Task moved to target section',
      conversation_id: conversation_id,
      task: task
    }.to_json
  else
    puts "\u274c Failed to move task #{task[:gid]} for conversation #{conversation_id}"
    status 500
    {
      status: 'error',
      message: 'Failed to move task',
      conversation_id: conversation_id,
      task: task
    }.to_json
  end
end

# Start the server
set :bind, '0.0.0.0'
set :port, ENV['PORT'] || 8080