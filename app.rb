# app.rb
require 'roda'
require 'json'
require 'logger'
require 'net/http'
require 'uri'
require_relative 'config'
#require 'byebug'

# Initialize Logger
LOGGER = Logger.new('proxy.log', 'daily') # Log rotation daily
MAX_LOG_SIZE = 1000 * 1024  # 1 MB

class App < Roda
  plugin :json_parser  # Parses JSON request bodies and makes them available in r.params
  plugin :streaming    # Enables streaming responses

  route do |r|
    # Initialize variables for error handling scope
    incoming_params = {}
    request_headers = {}

    # POST /v1/chat/completions
    r.post 'v1/chat/completions' do
      begin
        # Extract parameters from the incoming request
        incoming_params = r.params

        # Ensure all message roles that are not 'user' or 'assistant' are changed to 'user'
        if incoming_params['messages'].is_a?(Array)
          incoming_params['messages'].each do |message|
            if message['role'] != 'user' && message['role'] != 'assistant'
              message['role'] = 'user'
            end
          end
        end

        # Extract only 'model' and 'messages' from the incoming parameters
        allowed_params = {
          'model' => incoming_params['model'],
          'messages' => incoming_params['messages']
        }

        # Include 'stream' parameter if present
        allowed_params['stream'] = incoming_params['stream'] if incoming_params.key?('stream')

        # Validate that required parameters are present
        unless allowed_params['model'] && allowed_params['messages']
          response.status = 400
          response['Content-Type'] = 'application/json'

          error_message = { error: { message: "Both 'model' and 'messages' parameters are required." } }.to_json

          # Log the input and error
          LOGGER.error("Request Params: #{incoming_params.to_json}")
          LOGGER.error("Response: #{error_message}")

          return error_message
        end

        # Log the request content and headers
        request_headers = r.env.select { |k, _| k.start_with?('HTTP_') }.map do |k, v|
          header = k.sub(/^HTTP_/, '').split('_').map(&:capitalize).join('-')
          [header, v]
        end.to_h

        # Log the request body (input)
        LOGGER.info("Incoming Request Params: #{incoming_params.to_json}")
        LOGGER.info("Request Body: #{allowed_params.to_json}")
        LOGGER.info("Request Headers: #{request_headers.to_json}")

        # Prepare the URI and HTTP objects
        uri = URI('https://api.openai.com/v1/chat/completions')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        # Set the timeouts to the desired value (e.g., 600 seconds)
        http.open_timeout = 600  # Open timeout in seconds
        http.read_timeout = 600  # Read timeout in seconds
        http.write_timeout = 600 # Write timeout in seconds

        # Prepare the HTTP request
        request = Net::HTTP::Post.new(uri)
        request['Authorization'] = "Bearer #{ENV['OPENAI_API_KEY']}"
        request['Content-Type'] = 'application/json'

        # Check if 'stream' parameter is true
        if allowed_params['stream'] == true || allowed_params['stream'] == 'true'
          # Remove 'stream' from allowed_params
          allowed_params.delete('stream')
          request.body = allowed_params.to_json

          # Non-streaming request to OpenAI
          openai_response = http.request(request)
          response_body = openai_response.body

          # Now start the streaming process
          stream do |out|
            begin
              # Set the response status and headers before streaming begins
              response.status = openai_response.code.to_i

              # Exclude 'Content-Length' and 'Transfer-Encoding' headers
              excluded_headers = ['content-length', 'transfer-encoding']
              openai_response.each_header do |key, value|
                unless excluded_headers.include?(key.downcase)
                  response.headers[key] = value
                end
              end

              # Manually set 'Transfer-Encoding' to 'chunked'
              response.headers['Transfer-Encoding'] = 'chunked'
              response.headers['Content-Type'] = "text/event-stream; charset=utf-8"

              # Log the response headers
              LOGGER.info("Response Headers: #{response.headers.to_hash}")

              response_json = JSON.parse(response_body)

              modified_response_data = [
                {
                  id: response_json['id'],
                  object: "chat.completion.chunk",
                  created: response_json['created'],
                  model: response_json['model'],
                  system_fingerprint: response_json['system_fingerprint'],
                  choices: [
                    { index: 0, delta: { role: "assistant", content: "", refusal: nil}, logprobs: nil, finish_reason: nil}
                  ]
                },
                {
                  id: response_json['id'],
                  object: "chat.completion.chunk",
                  created: response_json['created'],
                  model: response_json['model'],
                  system_fingerprint: response_json['system_fingerprint'],
                  choices: [
                    { index: 0, delta: { content: response_json.dig("choices", 0, "message", "content") }, logprobs: nil, finish_reason: nil }
                  ]
                },
                {
                  id: response_json['id'],
                  object: "chat.completion.chunk",
                  created: response_json['created'],
                  model: response_json['model'],
                  system_fingerprint: response_json['system_fingerprint'],
                  choices: [{ index: 0, delta: {}, logprobs: nil, finish_reason: "stop" }]
                },
                "[DONE]"
              ]

              modified_response_body = modified_response_data.map { |i| "data: #{i.to_json}" }.join("\r\n\r\n")

              # Log the response body (trimmed if necessary)
              if modified_response_body.bytesize >= MAX_LOG_SIZE
                LOGGER.info("Response Body (truncated to #{MAX_LOG_SIZE} bytes): #{modified_response_body.byteslice(0, MAX_LOG_SIZE)}")
              else
                LOGGER.info("Response Body: #{modified_response_body}")
              end

              out.write(modified_response_body)
              out.write("\r\n\r\n")
            rescue StandardError => e
              # Log the error
              LOGGER.error("Streaming Error: #{e.message}")
              # Optionally, write an error message to the client
              out.write("data: {\"error\": \"#{e.message}\"}\n\n")
            end
          end

          # Return nil to avoid returning any unintended value
          nil
        else
          # Non-streaming response
          request.body = allowed_params.to_json

          # Send the request and get the response
          openai_response = http.request(request)

          # Set the response status code
          response.status = openai_response.code.to_i

          # Get the response body
          response_body = openai_response.body

          # Copy all headers from OpenAI's response to your response, excluding 'Transfer-Encoding' and 'Content-Length'
          excluded_headers = ['transfer-encoding', 'content-length']
          openai_response.each_header do |key, value|
            unless excluded_headers.include?(key.downcase)
              response.headers[key] = value
            end
          end

          # Set the correct Content-Length header
          response.headers['Content-Length'] = response_body.bytesize.to_s

          # Log the response headers
          LOGGER.info("Response Headers: #{response.headers.to_hash}")

          # Log the response body (output)
          LOGGER.info("Response Body: #{response_body}")

          # Return the response body
          response.write(response_body)
        end

      rescue StandardError => e
        # Set the HTTP status code to 500
        response.status = 500
        response['Content-Type'] = 'application/json'

        # Error message
        error_message = { error: { message: e.message } }.to_json

        # Log the error and request headers
        LOGGER.error("Request Params: #{incoming_params.to_json}")
        LOGGER.error("Request Headers: #{request_headers.to_json}")
        LOGGER.error("Error: #{e.message}")
        LOGGER.error("Backtrace:\n\t#{e.backtrace.join("\n\t")}")

        # Return an error message
        response.write(error_message)
      end
    end
  end
end
