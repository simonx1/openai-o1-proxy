Sure! Here’s an updated version of the `README.md` for the `openai-proxy` project based on the provided `app.rb` content. This will include a brief description, installation instructions, usage details, and information about logging.

```markdown
# openai-proxy

`openai-proxy` is a simple web proxy designed to relay requests between a client and the OpenAI API's chat completions endpoint. It provides a controlled interface, handling specific input validation and response processing, making it suitable for managing requests more effectively.

## Features

- **Request Validation:** Ensures that required parameters are present and modifies specific message roles for compliance.
- **Streaming Support:** Supports both streaming and non-streaming responses from the OpenAI API.
- **Logging:** Logs incoming requests, outgoing responses, and errors for monitoring and troubleshooting.
- **JSON Parsing:** Automatically parses JSON request bodies, allowing easy access to parameters.

## Installation

To get started with `openai-proxy`, first clone the repository:

```bash
git clone <repository-url>
cd openai-proxy
```

Next, install the required gems:

```bash
bundle install
```

Ensure you have the OpenAI API key set in your environment variables:

```bash
export OPENAI_API_KEY='your_openai_api_key'
```

## Usage

To run the proxy server, execute the following command:

```bash
ruby app.rb
```

The server will start and listen for incoming requests. You can make POST requests to the `/v1/chat/completions` endpoint, which should include a JSON payload containing the required parameters `model` and `messages`.

### Example Request

```bash
curl -X POST http://localhost:4567/v1/chat/completions \
-H "Content-Type: application/json" \
-d '{
  "model": "gpt-3.5-turbo",
  "messages": [{"role": "user", "content": "Hello, how are you?"}],
  "stream": true
}'
```

### Response

The response structure will match the OpenAI API output. When streaming is enabled, the response will be sent in chunks as they become available.

## Logging

All incoming requests, responses, and errors are logged to `proxy.log`. The logs are rotated daily, and the maximum log file size is set to 1 MB.

You can review the logs for troubleshooting and monitoring purposes:

```bash
tail -f proxy.log
```

## Error Handling

In case of an error during processing, the proxy will return a JSON error message with status code `500` and log detailed error information, including the request parameters and headers.

## License

This project is licensed under the MIT License.
```

Feel free to modify any sections to better fit your project's needs!