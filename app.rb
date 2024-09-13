# app.rb
require 'roda'
require 'json'
require 'logger'
require 'faraday'
require_relative 'config'

class App < Roda
  plugin :json_parser # Parses JSON request bodies and makes them available in r.params

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

        # Log the input
        LOGGER.info("Request Params: #{allowed_params.to_json}")

        # Set up Faraday client
        conn = Faraday.new(url: 'https://api.openai.com') do |faraday|
          faraday.request :json
          faraday.response :logger, LOGGER  # Optional: Logs Faraday request/response
          faraday.adapter Faraday.default_adapter
        end

        # Make the request to OpenAI API
        openai_response = conn.post('/v1/chat/completions') do |req|
          req.headers['Authorization'] = "Bearer #{ENV['OPENAI_API_KEY']}"
          req.headers['Content-Type'] = 'application/json'
          req.body = allowed_params.to_json
        end

        # Set the response status code and headers
        response.status = openai_response.status
        response['Content-Type'] = 'application/json'

        # Get the response body
        response_body = openai_response.body

        # Log the output
        LOGGER.info("Response: #{response_body}")

        # Return the OpenAI API response body
        response_body
      rescue Faraday::Error => e
        # Set the HTTP status code to match the error, default to 500
        response.status = 500
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
