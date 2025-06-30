require_relative 'test_helper'

class EndpointsTest < TestCase
  def setup
    super
    stub_asana_user_request
  end

  def test_root_endpoint
    get '/'
    
    assert last_response.ok?
    assert_equal 'application/json;charset=utf-8', last_response.content_type
    
    response_data = JSON.parse(last_response.body)
    assert_equal 'Intercom Webhook Handler', response_data['message']
    assert response_data['endpoints'].key?('webhook')
    assert response_data['endpoints'].key?('health')
    assert response_data['endpoints'].key?('debug')
  end

  def test_health_endpoint_with_configured_asana
    get '/health'
    
    assert last_response.ok?
    assert_equal 'application/json;charset=utf-8', last_response.content_type
    
    response_data = JSON.parse(last_response.body)
    assert_equal 'healthy', response_data['status']
    assert response_data['asana_client_configured']
    assert response_data['environment_check']['ASANA_ACCESS_TOKEN']
    assert response_data['environment_check']['ASANA_PROJECT_GID']
    assert response_data['environment_check']['ASANA_TARGET_SECTION_GID']
  end

  def test_health_endpoint_without_asana_token
    ENV.delete('ASANA_ACCESS_TOKEN')
    
    # Need to reload the app constants after changing env vars
    silence_warnings do
      load File.expand_path('../main.rb', __dir__)
    end
    
    get '/health'
    
    assert last_response.ok?
    response_data = JSON.parse(last_response.body)
    assert_equal 'healthy', response_data['status']
    refute response_data['asana_client_configured']
    refute response_data['environment_check']['ASANA_ACCESS_TOKEN']
  end

  def test_debug_endpoint
    get '/debug'
    
    assert last_response.ok?
    assert_equal 'application/json;charset=utf-8', last_response.content_type
    
    response_data = JSON.parse(last_response.body)
    assert_equal "***HIDDEN***", response_data['environment_variables']['ASANA_ACCESS_TOKEN']
    assert_equal 'test_project_gid', response_data['environment_variables']['ASANA_PROJECT_GID']
    assert_equal 'test_section_gid', response_data['environment_variables']['ASANA_TARGET_SECTION_GID']
    assert response_data['asana_client_initialized']
    assert response_data['ruby_version']
  end

  def test_debug_endpoint_without_tokens
    ENV.delete('ASANA_ACCESS_TOKEN')
    ENV.delete('INTERCOM_ACCESS_TOKEN')
    
    get '/debug'
    
    assert last_response.ok?
    response_data = JSON.parse(last_response.body)
    assert_equal 'NOT SET', response_data['environment_variables']['ASANA_ACCESS_TOKEN']
    assert_equal 'NOT SET', response_data['environment_variables']['INTERCOM_ACCESS_TOKEN']
  end

  def test_webhook_endpoint_with_invalid_json
    post '/intercom-webhook', 'invalid json'
    
    assert_equal 400, last_response.status
    response_data = JSON.parse(last_response.body)
    assert_equal 'error', response_data['status']
    assert_equal 'Invalid JSON', response_data['message']
  end

  def test_webhook_endpoint_without_conversation_id
    payload = { 'data' => { 'item' => {} } }
    
    post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    assert_equal 400, last_response.status
    response_data = JSON.parse(last_response.body)
    assert_equal 'error', response_data['status']
    assert_equal 'Conversation ID missing', response_data['message']
  end

  def test_webhook_endpoint_with_excluded_email
    payload = sample_webhook_payload_excluded_email
    
    post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    assert last_response.ok?
    response_data = JSON.parse(last_response.body)
    assert_equal 'skipped', response_data['status']
    assert_equal 'Author email in exclusion list', response_data['reason']
  end

  def test_webhook_endpoint_without_asana_client
    ENV.delete('ASANA_ACCESS_TOKEN')
    
    # Reload app to reinitialize without Asana client
    silence_warnings do
      load File.expand_path('../main.rb', __dir__)
    end
    
    payload = sample_webhook_payload
    
    post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    assert_equal 500, last_response.status
    response_data = JSON.parse(last_response.body)
    assert_equal 'error', response_data['status']
    assert_equal 'Asana client not configured', response_data['message']
  end

  def test_webhook_endpoint_task_not_found
    payload = sample_webhook_payload
    conversation_id = payload['data']['item']['id'].to_s
    
    # Mock AsanaClient to return nil for task search
    ASANA_CLIENT.stubs(:find_task_by_conversation_id).with(conversation_id).returns(nil)
    
    post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    assert_equal 404, last_response.status
    response_data = JSON.parse(last_response.body)
    assert_equal 'error', response_data['status']
    assert_equal 'Task not found for conversation', response_data['message']
    assert_equal conversation_id, response_data['conversation_id']
  end

  def test_webhook_endpoint_task_move_failure
    payload = sample_webhook_payload
    conversation_id = payload['data']['item']['id'].to_s
    task = { gid: 'task_123', name: 'Test Task' }
    
    # Mock AsanaClient methods
    ASANA_CLIENT.stubs(:find_task_by_conversation_id).with(conversation_id).returns(task)
    ASANA_CLIENT.stubs(:move_task_to_section).with('task_123').returns(false)
    
    post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    assert_equal 500, last_response.status
    response_data = JSON.parse(last_response.body)
    assert_equal 'error', response_data['status']
    assert_equal 'Failed to move task', response_data['message']
    assert_equal conversation_id, response_data['conversation_id']
    assert_equal task, response_data['task']
  end

  def test_webhook_endpoint_successful_task_move
    payload = sample_webhook_payload
    conversation_id = payload['data']['item']['id'].to_s
    task = { gid: 'task_123', name: 'Test Task' }
    
    # Mock AsanaClient methods
    ASANA_CLIENT.stubs(:find_task_by_conversation_id).with(conversation_id).returns(task)
    ASANA_CLIENT.stubs(:move_task_to_section).with('task_123').returns(true)
    
    post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    assert last_response.ok?
    response_data = JSON.parse(last_response.body)
    assert_equal 'success', response_data['status']
    assert_equal 'Task moved to target section', response_data['message']
    assert_equal conversation_id, response_data['conversation_id']
    assert_equal task, response_data['task']
  end

  private

  def silence_warnings
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = original_verbosity
  end
end