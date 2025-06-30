require_relative 'test_helper'

class AsanaClientTest < TestCase
  def setup
    super
    stub_asana_user_request
  end

  def test_initialization_with_valid_credentials
    client = AsanaClient.new
    assert_equal 'test_token', client.access_token
    assert_equal 'test_project_gid', client.project_gid
    assert_equal 'test_section_gid', client.target_section_gid
  end

  def test_initialization_without_access_token
    ENV.delete('ASANA_ACCESS_TOKEN')
    
    error = assert_raises(RuntimeError) do
      AsanaClient.new
    end
    assert_equal 'ASANA_ACCESS_TOKEN environment variable is required', error.message
  end

  def test_initialization_without_project_gid
    ENV.delete('ASANA_PROJECT_GID')
    
    error = assert_raises(RuntimeError) do
      AsanaClient.new
    end
    assert_equal 'ASANA_PROJECT_GID environment variable is required', error.message
  end

  def test_check_connection_success
    client = AsanaClient.new
    # Connection check is called during initialization, so if we get here it worked
    assert true
  end

  def test_check_connection_failure
    stub_request(:get, "https://app.asana.com/api/1.0/users/me")
      .to_return(status: 401, body: 'Unauthorized')

    error = assert_raises(RuntimeError) do
      AsanaClient.new
    end
    assert_equal 'Unable to connect to Asana', error.message
  end

  def test_extract_conversation_id_from_url
    client = AsanaClient.new
    
    url = "https://intercom.com/conversation/123456"
    assert_equal "123456", client.extract_conversation_id_from_url(url)
    
    assert_nil client.extract_conversation_id_from_url(nil)
    assert_nil client.extract_conversation_id_from_url("invalid-url")
  end

  def test_get_project_tasks
    tasks = [
      { 'gid' => 'task_1', 'name' => 'Task 1' },
      { 'gid' => 'task_2', 'name' => 'Task 2' }
    ]
    stub_asana_tasks_request(tasks)
    
    client = AsanaClient.new
    result = client.get_project_tasks
    
    assert_equal tasks, result
  end

  def test_get_project_tasks_api_error
    stub_request(:get, "https://app.asana.com/api/1.0/tasks")
      .to_return(status: 500, body: 'Server Error')
    
    client = AsanaClient.new
    result = client.get_project_tasks
    
    assert_equal [], result
  end

  def test_get_task_attachments
    attachments = [
      { 'gid' => 'att_1', 'name' => 'Attachment 1', 'url' => 'https://example.com' }
    ]
    stub_asana_attachments_request('task_123', attachments)
    
    client = AsanaClient.new
    result = client.get_task_attachments('task_123')
    
    assert_equal attachments, result
  end

  def test_find_task_by_conversation_id_success
    tasks = [{ 'gid' => 'task_123', 'name' => 'Test Task' }]
    attachments = [{
      'gid' => 'att_1',
      'name' => 'Intercom Link',
      'view_url' => 'https://intercom.com/conversation/4107'
    }]
    
    stub_asana_tasks_request(tasks)
    stub_asana_attachments_request('task_123', attachments)
    
    client = AsanaClient.new
    result = client.find_task_by_conversation_id('4107')
    
    expected = {
      gid: 'task_123',
      name: 'Test Task',
      attachment_gid: 'att_1',
      conversation_url: 'https://intercom.com/conversation/4107'
    }
    assert_equal expected, result
  end

  def test_find_task_by_conversation_id_not_found
    tasks = [{ 'gid' => 'task_123', 'name' => 'Test Task' }]
    attachments = []
    
    stub_asana_tasks_request(tasks)
    stub_asana_attachments_request('task_123', attachments)
    
    client = AsanaClient.new
    result = client.find_task_by_conversation_id('4107')
    
    assert_nil result
  end

  def test_move_task_to_section_success
    stub_asana_move_task_request('task_123')
    
    client = AsanaClient.new
    result = client.move_task_to_section('task_123')
    
    assert result
  end

  def test_move_task_to_section_failure
    stub_request(:post, "https://app.asana.com/api/1.0/sections/test_section_gid/addTask")
      .to_return(status: 400, body: 'Bad Request')
    
    client = AsanaClient.new
    result = client.move_task_to_section('task_123')
    
    refute result
  end

  def test_move_task_to_section_without_target_section
    ENV.delete('ASANA_TARGET_SECTION_GID')
    client = AsanaClient.new
    result = client.move_task_to_section('task_123')
    
    refute result
  end

  def test_move_task_to_custom_section
    stub_asana_move_task_request('task_123', 'custom_section')
    
    client = AsanaClient.new
    result = client.move_task_to_section('task_123', 'custom_section')
    
    assert result
  end

  def test_get_task_details
    task_details = {
      'gid' => 'task_123',
      'name' => 'Test Task',
      'notes' => 'Task notes',
      'completed' => false
    }
    
    stub_request(:get, "https://app.asana.com/api/1.0/tasks/task_123")
      .with(
        query: { 'opt_fields' => 'gid,name,notes,completed,assignee,due_on,projects' },
        headers: { 'Authorization' => 'Bearer test_token' }
      )
      .to_return(
        status: 200,
        body: { data: task_details }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    client = AsanaClient.new
    result = client.get_task_details('task_123')
    
    assert_equal task_details, result
  end

  def test_get_user_info
    user_info = { 'gid' => 'user_123', 'name' => 'Test User' }
    
    # Override the stub from setup to return specific user info
    stub_request(:get, "https://app.asana.com/api/1.0/users/me")
      .with(headers: { 'Authorization' => 'Bearer test_token' })
      .to_return(
        status: 200,
        body: { data: user_info }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    client = AsanaClient.new
    result = client.get_user_info
    
    assert_equal user_info, result
  end
end