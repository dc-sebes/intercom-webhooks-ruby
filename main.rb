require 'puma'
require 'sinatra'
require 'json'
require 'dotenv/load'
require_relative './asana_client'

# Список email'ов, для которых НЕ нужно выполнять перенос задач в Asana
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
      puts "✅ Asana клиент успешно инициализирован"
      return client
    rescue => e 
      puts "❌ Ошибка при инициализации Asana: #{e}"
      nil
    end
  else
    puts "❌ Asana клиент не инициализирован - отсутствует ASANA_ACCESS_TOKEN"
    nil
  end
end


def init_intercom_client
  if ENV['INTERCOM_ACCESS_TOKEN']
    puts "✅ Intercom клиент успешно инициализирован"
    #IntercomClient.new
  else
    puts "❌ Intercom клиент не инициализирован - отсутствует INTERCOM_ACCESS_TOKEN"
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
      ASANA_ACCESS_TOKEN: ENV['ASANA_ACCESS_TOKEN'] ? "***СКРЫТО***" : "НЕ УСТАНОВЛЕН",
      ASANA_PROJECT_GID: ENV['ASANA_PROJECT_GID'] || 'НЕ УСТАНОВЛЕН',
      ASANA_TARGET_SECTION_GID: ENV['ASANA_TARGET_SECTION_GID'] || 'НЕ УСТАНОВЛЕН',
      PORT: ENV['PORT'] || 'НЕ УСТАНОВЛЕН',
      DEBUG: ENV['DEBUG'] || 'НЕ УСТАНОВЛЕН',
      INTERCOM_ACCESS_TOKEN: ENV['INTERCOM_ACCESS_TOKEN'] || 'НЕ УСТАНОВЛЕН'
    },
    asana_client_initialized: !!ASANA_CLIENT,
    ruby_version: RUBY_VERSION
  }.to_json
end

# Корневой эндпоинт
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

post '/intercom-webhook' do
  content_type :json
  data = JSON.parse(request.body.read) rescue {}
  puts "Webhook получен: #{data.inspect}"
  { status: 'ok', message: 'Webhook обработан (логика будет позже)' }.to_json
end

# Запуск сервера
set :bind, '0.0.0.0'
set :port, ENV['PORT'] || 8080