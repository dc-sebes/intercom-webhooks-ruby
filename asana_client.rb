require 'json'
require 'net/http'
require 'uri'

class AsanaClient
  attr_reader :access_token, :target_section_gid, :project_gid

  def initialize
    puts '=== Initializing AsanaClient ==='
    @access_token = ENV['ASANA_ACCESS_TOKEN']
    @target_section_gid = ENV['ASANA_TARGET_SECTION_GID']
    @project_gid = ENV['ASANA_PROJECT_GID']

    raise 'ASANA_ACCESS_TOKEN environment variable is required' unless @access_token
    raise 'ASANA_PROJECT_GID environment variable is required' unless @project_gid

    @base_url = 'https://app.asana.com/api/1.0'
    @headers = {
      'Authorization' => "Bearer #{@access_token}",
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }

    check_connection
    puts '=== AsanaClient initialized ==='
  end

  def check_connection
    res = request(:get, '/users/me')
    if res && res['data']
      puts "\u2705 Asana connection OK! User: #{res['data']['name']}"
    else
      raise 'Unable to connect to Asana'
    end
  end

  def request(method, endpoint, data: nil, params: nil)
    uri = URI.join(@base_url + '/', endpoint.sub(%r{^/}, ''))
    uri.query = URI.encode_www_form(params) if params

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req_class = case method.to_s.upcase
                when 'GET' then Net::HTTP::Get
                when 'POST' then Net::HTTP::Post
                when 'PUT' then Net::HTTP::Put
                else raise ArgumentError, "Unsupported HTTP method: #{method}"
                end
    req = req_class.new(uri)
    @headers.each { |k, v| req[k] = v }
    req.body = JSON.dump(data) if data

    res = http.request(req)

    case res
    when Net::HTTPSuccess, Net::HTTPCreated
      JSON.parse(res.body)
    else
      puts "\u274c Asana API error: #{res.code} - #{res.body}"
      nil
    end
  rescue StandardError => e
    puts "\u274c Error in Asana request: #{e}"
    nil
  end

  def extract_conversation_id_from_url(url)
    return nil unless url
    m = url.match(/\/conversation\/(\d+)/)
    m && m[1]
  end

  def get_project_tasks
    params = {
      'project' => @project_gid,
      'opt_fields' => 'gid,name',
      'limit' => 100
    }
    res = request(:get, '/tasks', params: params)
    res ? res['data'] : []
  end

  def get_task_attachments(task_gid)
    params = {
      'parent' => task_gid,
      'opt_fields' => 'gid,name,resource_type,resource_subtype,url,view_url,host'
    }
    res = request(:get, '/attachments', params: params)
    res ? res['data'] : []
  end

  def find_task_by_conversation_id(conversation_id)
    tasks = get_project_tasks
    tasks.each do |task|
      attachments = get_task_attachments(task['gid'])
      attachments.each do |attachment|
        %w[view_url url].each do |field|
          url = attachment[field]
          next unless url
          extracted = extract_conversation_id_from_url(url)
          if extracted == conversation_id.to_s
            return {
              gid: task['gid'],
              name: task['name'],
              attachment_gid: attachment['gid'],
              conversation_url: url
            }
          end
        end
      end
    end
    nil
  end

  def move_task_to_section(task_gid, section_gid = nil)
    target = section_gid || @target_section_gid
    return false unless target

    data = { data: { task: task_gid } }
    !!request(:post, "/sections/#{target}/addTask", data: data)
  end

  def get_task_details(task_gid)
    params = {
      'opt_fields' => 'gid,name,notes,completed,assignee,due_on,projects'
    }
    res = request(:get, "/tasks/#{task_gid}", params: params)
    res ? res['data'] : nil
  end

  def get_user_info
    res = request(:get, '/users/me')
    res ? res['data'] : nil
  end
end
