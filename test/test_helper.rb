require 'minitest/autorun'
require 'rack/test'
require 'webmock/minitest'
require 'mocha/minitest'
require 'json'
require 'dotenv/load'

# Require the main application files
require_relative '../main'
require_relative '../asana_client'

class TestCase < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    WebMock.disable_net_connect!(allow_localhost: true)
    # Set up test environment variables
    ENV['ASANA_ACCESS_TOKEN'] = 'test_token'
    ENV['ASANA_PROJECT_GID'] = 'test_project_gid'
    ENV['ASANA_TARGET_SECTION_GID'] = 'test_section_gid'
    ENV['INTERCOM_ACCESS_TOKEN'] = 'test_intercom_token'
  end

  def teardown
    WebMock.reset!
  end

  def sample_webhook_payload
    JSON.parse(File.read(File.join(__dir__, '..', 'test.json')))
  end

  def sample_webhook_payload_excluded_email
    payload = sample_webhook_payload
    payload['data']['item']['conversation_parts']['conversation_parts'][0]['author'] = {
      'id' => '123',
      'type' => 'user',
      'name' => 'Test User',
      'email' => 'i.konovalov@sebestech.com'
    }
    payload
  end

  def stub_asana_user_request
    stub_request(:get, "https://app.asana.com/api/1.0/users/me")
      .with(headers: { 'Authorization' => 'Bearer test_token' })
      .to_return(
        status: 200,
        body: { data: { name: 'Test User', gid: 'user_123' } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_asana_tasks_request(tasks = [])
    stub_request(:get, "https://app.asana.com/api/1.0/tasks")
      .with(
        query: {
          'project' => 'test_project_gid',
          'opt_fields' => 'gid,name',
          'limit' => 100
        },
        headers: { 'Authorization' => 'Bearer test_token' }
      )
      .to_return(
        status: 200,
        body: { data: tasks }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_asana_attachments_request(task_gid, attachments = [])
    stub_request(:get, "https://app.asana.com/api/1.0/attachments")
      .with(
        query: {
          'parent' => task_gid,
          'opt_fields' => 'gid,name,resource_type,resource_subtype,url,view_url,host'
        },
        headers: { 'Authorization' => 'Bearer test_token' }
      )
      .to_return(
        status: 200,
        body: { data: attachments }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  def stub_asana_move_task_request(task_gid, section_gid = 'test_section_gid')
    stub_request(:post, "https://app.asana.com/api/1.0/sections/#{section_gid}/addTask")
      .with(
        body: { data: { task: task_gid } }.to_json,
        headers: { 
          'Authorization' => 'Bearer test_token',
          'Content-Type' => 'application/json'
        }
      )
      .to_return(
        status: 200,
        body: { data: {} }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end