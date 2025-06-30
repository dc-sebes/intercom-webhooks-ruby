require_relative 'test_helper'

class IntegrationTest < TestCase
  def setup
    super
    stub_asana_user_request
  end

  def test_complete_webhook_flow_with_task_found_and_moved
    # Setup the complete flow with real HTTP stubs
    conversation_id = '4107'
    task_gid = 'task_12345'
    
    # Stub the complete Asana API chain
    tasks = [{ 'gid' => task_gid, 'name' => 'Customer Support Task' }]
    attachments = [{
      'gid' => 'att_123',
      'name' => 'Intercom Conversation',
      'view_url' => "https://intercom.com/conversation/#{conversation_id}"
    }]
    
    stub_asana_tasks_request(tasks)
    stub_asana_attachments_request(task_gid, attachments)
    stub_asana_move_task_request(task_gid)
    
    # Send the webhook
    payload = sample_webhook_payload
    post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    # Verify the response
    assert last_response.ok?
    response_data = JSON.parse(last_response.body)
    
    assert_equal 'success', response_data['status']
    assert_equal 'Task moved to target section', response_data['message']
    assert_equal conversation_id, response_data['conversation_id']
    assert_equal task_gid, response_data['task'][:gid]
    assert_equal 'Customer Support Task', response_data['task'][:name]
    assert_equal 'att_123', response_data['task'][:attachment_gid]
    assert_equal "https://intercom.com/conversation/#{conversation_id}", response_data['task'][:conversation_url]
    
    # Verify all the expected API calls were made
    assert_requested(:get, "https://app.asana.com/api/1.0/users/me")
    assert_requested(:get, "https://app.asana.com/api/1.0/tasks") do |req|
      req.uri.query.include?("project=test_project_gid")
    end
    assert_requested(:get, "https://app.asana.com/api/1.0/attachments") do |req|
      req.uri.query.include?("parent=#{task_gid}")
    end
    assert_requested(:post, "https://app.asana.com/api/1.0/sections/test_section_gid/addTask") do |req|
      body = JSON.parse(req.body)
      body['data']['task'] == task_gid
    end
  end

  def test_complete_webhook_flow_with_multiple_tasks_and_attachments
    # Test scenario where we have multiple tasks and need to search through attachments
    conversation_id = '4107'
    target_task_gid = 'task_target'
    
    tasks = [
      { 'gid' => 'task_1', 'name' => 'Unrelated Task 1' },
      { 'gid' => target_task_gid, 'name' => 'Target Task' },
      { 'gid' => 'task_3', 'name' => 'Unrelated Task 2' }
    ]
    
    # First task has no attachments
    stub_asana_attachments_request('task_1', [])
    
    # Target task has the matching attachment
    target_attachments = [{
      'gid' => 'att_target',
      'name' => 'Intercom Link',
      'url' => "https://intercom.com/conversation/#{conversation_id}"
    }]
    stub_asana_attachments_request(target_task_gid, target_attachments)
    
    # Third task has different attachment
    other_attachments = [{
      'gid' => 'att_other',
      'name' => 'Other Link',
      'view_url' => 'https://intercom.com/conversation/9999'
    }]
    stub_asana_attachments_request('task_3', other_attachments)
    
    stub_asana_tasks_request(tasks)
    stub_asana_move_task_request(target_task_gid)
    
    payload = sample_webhook_payload
    post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    assert last_response.ok?
    response_data = JSON.parse(last_response.body)
    
    assert_equal 'success', response_data['status']
    assert_equal target_task_gid, response_data['task'][:gid]
    assert_equal 'Target Task', response_data['task'][:name]
    
    # Verify all tasks were searched
    assert_requested(:get, "https://app.asana.com/api/1.0/attachments", times: 3)
  end

  def test_complete_webhook_flow_with_excluded_email_addresses
    # Test all excluded email addresses
    excluded_emails = [
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
    
    excluded_emails.each do |email|
      payload = sample_webhook_payload
      payload['data']['item']['conversation_parts']['conversation_parts'][0]['author']['email'] = email
      
      post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      
      assert last_response.ok?
      response_data = JSON.parse(last_response.body)
      assert_equal 'skipped', response_data['status']
      assert_equal 'Author email in exclusion list', response_data['reason']
    end
  end

  def test_complete_webhook_flow_case_insensitive_email_exclusion
    # Test that email exclusion is case insensitive
    payload = sample_webhook_payload
    payload['data']['item']['conversation_parts']['conversation_parts'][0]['author']['email'] = 'I.KONOVALOV@SEBESTECH.COM'
    
    post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    assert last_response.ok?
    response_data = JSON.parse(last_response.body)
    assert_equal 'skipped', response_data['status']
  end

  def test_webhook_flow_with_network_failures
    # Test resilience to network failures in Asana API
    conversation_id = '4107'
    
    # Stub network failure for tasks request
    stub_request(:get, "https://app.asana.com/api/1.0/tasks")
      .to_timeout
    
    payload = sample_webhook_payload
    post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
    
    assert_equal 404, last_response.status
    response_data = JSON.parse(last_response.body)
    assert_equal 'error', response_data['status']
    assert_equal 'Task not found for conversation', response_data['message']
  end

  def test_webhook_flow_with_malformed_intercom_payload_structures
    # Test various malformed payload structures
    malformed_payloads = [
      { 'data' => nil },
      { 'data' => { 'item' => nil } },
      { 'data' => { 'item' => { 'conversation_parts' => nil } } },
      { 'data' => { 'item' => { 'conversation_parts' => { 'conversation_parts' => [] } } } },
      { 'data' => { 'item' => { 'id' => '123', 'conversation_parts' => { 'conversation_parts' => [{ 'author' => nil }] } } } }
    ]
    
    malformed_payloads.each_with_index do |payload, index|
      post '/intercom-webhook', payload.to_json, { 'CONTENT_TYPE' => 'application/json' }
      
      # Most should result in either missing conversation ID or be processed normally
      # The key is that none should cause crashes
      assert [200, 400].include?(last_response.status), "Payload #{index} caused unexpected status: #{last_response.status}"
    end
  end

  def test_health_check_integration
    get '/health'
    
    assert last_response.ok?
    response_data = JSON.parse(last_response.body)
    
    assert_equal 'healthy', response_data['status']
    assert response_data.key?('asana_client_configured')
    assert response_data.key?('environment_check')
    
    env_check = response_data['environment_check']
    assert env_check.key?('ASANA_ACCESS_TOKEN')
    assert env_check.key?('ASANA_PROJECT_GID')
    assert env_check.key?('ASANA_TARGET_SECTION_GID')
  end

  def test_debug_endpoint_security
    # Ensure sensitive data is properly masked
    get '/debug'
    
    assert last_response.ok?
    response_data = JSON.parse(last_response.body)
    
    env_vars = response_data['environment_variables']
    
    # API tokens should be masked
    assert_equal '***HIDDEN***', env_vars['ASANA_ACCESS_TOKEN']
    
    # Other config should be visible
    assert_equal 'test_project_gid', env_vars['ASANA_PROJECT_GID']
    assert_equal 'test_section_gid', env_vars['ASANA_TARGET_SECTION_GID']
    
    # System info should be present
    assert response_data.key?('ruby_version')
    assert response_data.key?('asana_client_initialized')
  end
end