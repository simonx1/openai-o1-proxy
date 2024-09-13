# app.rb
require 'roda'
require 'json'
require 'logger'
require_relative 'config'

class App < Roda
  plugin :json_parser # Parses JSON request bodies and makes them available in r.params

  # Initialize Logger
  LOGGER = Logger.new('proxy.log', 'daily') # Log rotation daily

  route do |r|
    # POST /v1/chat/completions
    r.post 'v1/chat/completions' do
      client = OpenAI::Client.new

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

        # Log the input
        LOGGER.info("Request Params: #{allowed_params.to_json}")

        # Forward the filtered parameters to OpenAI's API
        openai_response = client.chat(parameters: allowed_params)

        # Set the response status code and headers
        response.status = openai_response.status
        response['Content-Type'] = 'application/json'

        # Get the response body
        response_body = openai_response.body

        # Log the output
        LOGGER.info("Response: #{response_body}")

        # Return the OpenAI API response body
        response_body
      rescue OpenAI::Error => e
        # Set the HTTP status code to match the error, default to 500
        response.status = e.respond_to?(:http_code) ? e.http_code : 500
        response['Content-Type'] = 'application/json'

        # Error message
        error_message = { error: { message: e.message } }.to_json

        # Log the error
        LOGGER.error("Request Params: #{r.params.to_json}")
        LOGGER.error("Error: #{e.message}")

        # Return an error message
        error_message
      end
    end
  end
end
