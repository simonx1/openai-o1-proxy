## OpenAI o1 proxy

`openai-o1-proxy` is a simple web proxy designed to relay requests between a client and the OpenAI API's chat completions endpoint. 
It is specifically desigend for new OpenAI models: `o1-preview` and `o1-mini` as they are not fully compatibile with OpenAI completion API.

This proxy addresses three main issues of o1 models:
1. Lack of streaming capability - entire response is streamed back if the `stream` param was set to true. This enables using OpenAI new models in `Continue` IDE plugin
2. Handling only `user` and `assistant` roles.
3. Parameters like `temperature` or `top_p` are fixed and removed from API.

## Features

- **Request Validation:** Ensures that required parameters are present and modifies specific message roles for compliance.
- **Streaming Support:** Supports both streaming and non-streaming responses from the OpenAI API.
- **Logging:** Logs incoming requests, outgoing responses, and errors for monitoring and troubleshooting.
- **JSON Parsing:** Automatically parses JSON request bodies, allowing easy access to parameters.

## Installation

To get started with `openai-proxy`, first clone the repository:

```bash
git clone <repository-url>
cd openai-o1-proxy
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
puma -p 4567
```

The server will start and listen for incoming requests. You can make POST requests to the `/v1/chat/completions` endpoint, which should include a JSON payload containing the required parameters `model` and `messages`.

### Example Request

```bash
curl -X POST http://localhost:4567/v1/chat/completions \
-H "Content-Type: application/json" \
-d '{
  "model": "o1-mini",
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

## `Continue` IDE plugin config
```bash
    {
      "model": "o1-mini",
      "title": "ChatGPT o1 Mini",
      "provider": "openai",
      "apiKey": "none",
      "useLegacyCompletionsEndpoint": false,
      "apiBase": "http://0.0.0.0:4567/v1"
    },
```

## License

This project is licensed under the MIT License.
