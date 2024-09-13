# app.rb
require 'roda'
require 'json'
require_relative 'config'

class App < Roda
  plugin :json_parser # Parses JSON request bodies and makes them available in r.params
  plugin :json        # Automatically serializes hashes to JSON responses

  route do |r|
    # POST /v1/chat/completion
    r.post 'v1/chat/completion' do
      client = OpenAI::Client.new

      begin
        # Extract only 'model' and 'messages' from the incoming parameters
        allowed_params = {
          'model' => r.params['model'],
          'messages' => r.params['messages']
        }

        # Optional: Validate that required parameters are present
        unless allowed_params['model'] && allowed_params['messages']
          response.status = 400
          return { error: { message: "Both 'model' and 'messages' parameters are required." } }
        end

        # Forward the filtered parameters to OpenAI's API
        openai_response = client.chat(parameters: allowed_params)

        # Return the OpenAI API response
        openai_response
      rescue OpenAI::Error => e
        # Set the HTTP status code to 500 Internal Server Error
        response.status = 500

        # Return an error message
        { error: { message: e.message } }
      end
    end
  end
end

