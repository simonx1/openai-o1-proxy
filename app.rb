# app.rb
require 'roda'
require 'json'
require 'logger'
require 'net/http'
require 'uri'
require_relative 'config'

class App < Roda
  plugin :json_parser  # Parses JSON request bodies and makes them available in r.params
  plugin :streaming    # Enables streaming responses

  # Initialize Logger
  LOGGER = Logger.new('proxy.log', 'daily') # Log rotation daily

  route do |r|
    # POST /v1/chat/completions
    r.post 'v1/chat/completions' do
      begin
        # Extract only 'model' and 'messages' from the incoming parameters
        allowed_params = {
          'model' => r.params['model'],
          'messages' => r.params['messages']
        }

        # Validate that required parameters are present
        unless allowed_params['model'] && allowed_params['messages']
          response.status = 400
          response['Content-Type'] = 'application/json'

          error_message = { error: { message: "Both 'model' and 'messages' parameters are required." } }.to_json

          # Log the input and error
          LOGGER.error("Request Params: #{r.params.to_json}")
          LOGGER.error("Response: #{error_message}")

          return error_message
        end

        # Log the request content and headers
        request_headers = r.env.select { |k, _| k.start_with?('HTTP_') }.map do |k, v|
          header = k.sub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
          [header, v]
        end.to_h

        # Log the request body (input)
        LOGGER.info("Original Request Params: #{r.params.to_json}")
        LOGGER.info("Request Body: #{allowed_params.to_json}")
        LOGGER.info("Request Headers: #{request_headers.to_json}")

        # Prepare the URI and HTTP objects
        uri = URI('https://api.openai.com/v1/chat/completions')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        # Optional: Logs Net::HTTP request/response
        # http.set_debug_output(LOGGER)

        # Prepare the HTTP request
        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{ENV['OPENAI_API_KEY']}"
        request['Content-Type'] = 'application/json'
        request.body = allowed_params.to_json

        # Initialize variable to accumulate response body for logging
        response_body = ''

        # Stream the response
        stream do |out|
          http.request(request) do |openai_response|
            # Set the response status code
            response.status = openai_response.code.to_i

            # Copy all headers from OpenAI's response to your response
            openai_response.each_header do |key, value|
              response.headers[key] = value
            end

            # Log the response headers
            LOGGER.info("Response Headers: #{response.headers.to_hash}")

            # Stream the response body and accumulate for logging
            openai_response.read_body do |chunk|
              out.write(chunk)
              response_body << chunk
            end

            # After streaming, log the response body (output)
            LOGGER.info("Response Body: #{response_body}")
          end
        end

        # Return nil to avoid returning any unintended value
        nil
      rescue StandardError => e
        # Set the HTTP status code to 500
        response.status = 500
        response['Content-Type'] = 'application/json'

        # Error message
        error_message = { error: { message: e.message } }.to_json

        # Log the error and request headers
        LOGGER.error("Request Params: #{r.params.to_json}")
        LOGGER.error("Request Headers: #{request_headers.to_json}")
        LOGGER.error("Error: #{e.message}")

        # Return an error message
        error_message
      end
    end
  end
end
