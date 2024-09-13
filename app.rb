# app.rb
require 'roda'
require 'json'
require 'logger'
require 'rack/proxy'
require_relative 'config'

class App < Roda
  plugin :json_parser # Parses JSON request bodies and makes them available in r.params
  plugin :streaming   # Enables streaming responses

  # Initialize Logger
  LOGGER = Logger.new('proxy.log', 'daily') # Log rotation daily

  class OpenAIProxy < Rack::Proxy
    def initialize
      @logger = LOGGER
      super()
    end

    def perform_request(env)
      request = Rack::Request.new(env)

      if env['REQUEST_METHOD'] == 'POST' && env['PATH_INFO'] == '/v1/chat/completions'
        # Read the request body
        request_body = request.body.read
        params = JSON.parse(request_body)

        # Extract only 'model' and 'messages' from the incoming parameters
        allowed_params = {
          'model' => params['model'],
          'messages' => params['messages']
        }

        # Validate that required parameters are present
        unless allowed_params['model'] && allowed_params['messages']
          error_message = { error: { message: "Both 'model' and 'messages' parameters are required." } }.to_json
          @logger.error("Request Params: #{params.to_json}")
          @logger.error("Response: #{error_message}")
          return [400, { 'Content-Type' => 'application/json' }, [error_message]]
        end

        # Log the input
        @logger.info("Request Params: #{allowed_params.to_json}")

        # Modify the env for proxying
        env['HTTP_HOST'] = 'api.openai.com'
        env['PATH_INFO'] = '/v1/chat/completions'
        env['HTTP_AUTHORIZATION'] = "Bearer #{ENV['OPENAI_API_KEY']}"
        env['REQUEST_PATH'] = '/v1/chat/completions'
        env['SERVER_PORT'] = '443'
        env['HTTPS'] = 'on'
        env['rack.url_scheme'] = 'https'

        # Replace the request body
        env['rack.input'] = StringIO.new(allowed_params.to_json)
        env['CONTENT_LENGTH'] = allowed_params.to_json.bytesize.to_s

        # Remove Connection headers if present
        env.delete('HTTP_CONNECTION')
        env.delete('HTTP_KEEP_ALIVE')

        # Perform the proxy request
        super(env)
      else
        # For other paths, return 404 Not Found
        [404, { 'Content-Type' => 'application/json' }, [{ error: { message: 'Not Found' } }.to_json]]
      end
    end
  end

  route do |r|
    # Initialize the proxy
    proxy = OpenAIProxy.new

    # Call the proxy and get the response
    status, headers, body = proxy.call(r.env)

    # Set the response status and headers
    response.status = status.to_i
    headers.each { |k, v| response.headers[k] = v }

    # Stream the response body
    stream do |out|
      body.each do |chunk|
        out << chunk
      end
      body.close if body.respond_to?(:close)
    end
  end
end
