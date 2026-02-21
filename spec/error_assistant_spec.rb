require 'spec_helper'
require_relative '../app/lib/origen_llm'

# Unit tests for OrigenLlm::ErrorAssistant
# All API calls are mocked - no live endpoints are hit
describe OrigenLlm::ErrorAssistant do
  describe '.analyze' do
    let(:exception_message) { "NoMethodError: undefined method `foo' for nil:NilClass" }
    let(:app_stack) do
      [
        "/path/to/app/lib/my_module.rb:42:in `process'",
        "/path/to/app/lib/my_module.rb:20:in `run'",
        "/path/to/app/bin/my_app:10:in `<main>'"
      ]
    end

    context 'with no API configured' do
      it 'returns nil when api_url is empty' do
        result = OrigenLlm::ErrorAssistant.analyze(
          exception_message: exception_message,
          app_stack: app_stack,
          context: { api_url: '' }
        )
        result.should be_nil
      end

      it 'returns nil when api_url is nil' do
        result = OrigenLlm::ErrorAssistant.analyze(
          exception_message: exception_message,
          app_stack: app_stack,
          context: {}
        )
        result.should be_nil
      end
    end

    context 'with mocked API response' do
      before do
        # Mock the HTTP response - no actual network calls
        mock_response = double('response')
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(mock_response).to receive(:body).and_return('{"answer": "Test suggestion"}')

        allow(Net::HTTP).to receive(:start).and_yield(double('http').tap do |http|
          allow(http).to receive(:request).and_return(mock_response)
        end)
      end

      it 'returns normalized response' do
        result = OrigenLlm::ErrorAssistant.analyze(
          exception_message: exception_message,
          app_stack: app_stack,
          context: { api_url: 'https://test.com/api' }
        )
        result.should == 'Test suggestion'
      end
    end

    context 'response normalization' do
      it 'returns nil for nil response' do
        result = OrigenLlm::ErrorAssistant.send(:normalize_response, nil)
        result.should be_nil
      end

      it 'returns nil for empty string response' do
        result = OrigenLlm::ErrorAssistant.send(:normalize_response, '   ')
        result.should be_nil
      end

      it 'strips whitespace from valid response' do
        result = OrigenLlm::ErrorAssistant.send(:normalize_response, "  Test response  \n")
        result.should == 'Test response'
      end
    end
  end
end

describe OrigenLlm::ErrorAssistantPrompt do
  describe '.build' do
    let(:exception_message) { 'RuntimeError: Something went wrong' }
    let(:app_stack) do
      [
        "/app/lib/module.rb:10:in `method'",
        "/app/lib/runner.rb:5:in `run'"
      ]
    end

    context 'default mode' do
      it 'builds a structured prompt' do
        prompt = OrigenLlm::ErrorAssistantPrompt.build(
          exception_message: exception_message,
          app_stack: app_stack
        )

        prompt.should include('You are diagnosing an Origen application runtime failure')
        prompt.should include('Most likely root cause')
        prompt.should include('Suggested fix steps')
        prompt.should include('Confidence')
        prompt.should include(exception_message)
        prompt.should include(app_stack.join("\n"))
      end
    end

    context 'site_template mode' do
      let(:template) { "Error: %<exception_message>s\nStack:\n%<application_stack>s\nPlease fix this." }

      it 'uses the provided template' do
        prompt = OrigenLlm::ErrorAssistantPrompt.build(
          exception_message: exception_message,
          app_stack: app_stack,
          mode: 'site_template',
          site_template: template
        )

        expected = "Error: #{exception_message}\nStack:\n#{app_stack.join("\n")}\nPlease fix this."
        prompt.should == expected
      end

      it 'falls back to default when template is empty' do
        prompt = OrigenLlm::ErrorAssistantPrompt.build(
          exception_message: exception_message,
          app_stack: app_stack,
          mode: 'site_template',
          site_template: ''
        )

        prompt.should include('You are diagnosing an Origen application runtime failure')
      end
    end
  end
end

describe OrigenLlm::ErrorAssistantClient do
  let(:exception_message) { 'Test error' }
  let(:app_stack) { ['/test.rb:1'] }

  describe '#initialize' do
    it 'initializes with default values' do
      client = OrigenLlm::ErrorAssistantClient.new(context: {})
      client.should be_a(OrigenLlm::ErrorAssistantClient)
    end

    it 'accepts custom configuration' do
      client = OrigenLlm::ErrorAssistantClient.new(context: {
                                                     api_url: 'https://example.com/api',
                                                     model: 'gpt-4',
                                                     max_tokens: 500,
                                                     temperature: 0.7,
                                                     api_key_env: 'TEST_KEY',
                                                     provider_mode: 'anthropic_messages'
                                                   })
      client.should be_a(OrigenLlm::ErrorAssistantClient)
    end

    it 'handles invalid numeric values with defaults' do
      client = OrigenLlm::ErrorAssistantClient.new(context: {
                                                     max_tokens: 'invalid',
                                                     temperature: 'not_a_number',
                                                     timeout_seconds: nil
                                                   })
      client.should be_a(OrigenLlm::ErrorAssistantClient)
    end
  end

  describe '#analyze with mocked responses' do
    let(:client) { OrigenLlm::ErrorAssistantClient.new(context: { api_url: 'https://test.com' }) }

    context 'with no API URL' do
      it 'returns nil' do
        client = OrigenLlm::ErrorAssistantClient.new(context: {})
        result = client.analyze(
          prompt: 'Test prompt',
          exception_message: exception_message,
          app_stack: app_stack
        )
        result.should be_nil
      end
    end

    context 'with failed HTTP request (mocked)' do
      before do
        mock_response = double('response')
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

        allow(Net::HTTP).to receive(:start).and_yield(double('http').tap do |http|
          allow(http).to receive(:request).and_return(mock_response)
        end)
      end

      it 'returns nil' do
        result = client.analyze(
          prompt: 'Test prompt',
          exception_message: exception_message,
          app_stack: app_stack
        )
        result.should be_nil
      end
    end
  end

  describe 'private methods' do
    context 'authentication header building' do
      it 'builds x_api_key header correctly' do
        ENV['TEST_KEY'] = 'secret123'
        client = OrigenLlm::ErrorAssistantClient.new(context: {
                                                       api_key_env: 'TEST_KEY',
                                                       auth_mode: 'x_api_key'
                                                     })

        headers = client.send(:build_headers)
        headers['X-API-Key'].should == 'secret123'

        ENV.delete('TEST_KEY')
      end

      it 'builds bearer header correctly' do
        ENV['TEST_KEY'] = 'secret123'
        client = OrigenLlm::ErrorAssistantClient.new(context: {
                                                       api_key_env: 'TEST_KEY',
                                                       auth_mode: 'bearer'
                                                     })

        headers = client.send(:build_headers)
        headers['Authorization'].should == 'Bearer secret123'

        ENV.delete('TEST_KEY')
      end
    end

    context 'payload building' do
      it 'builds generic provider payload' do
        client = OrigenLlm::ErrorAssistantClient.new(context: {
                                                       model: 'test-model'
                                                     })

        payload = client.send(:build_request_payload,
                              prompt: 'Test prompt',
                              exception_message: exception_message,
                              app_stack: app_stack)

        payload[:question].should == 'Test prompt'
        payload[:model].should == 'test-model'
        payload[:context][:exception_message].should == exception_message
        payload[:context][:application_stack].should == app_stack
      end

      it 'builds anthropic payload' do
        client = OrigenLlm::ErrorAssistantClient.new(context: {
                                                       provider_mode: 'anthropic_messages',
                                                       model: 'claude-3',
                                                       max_tokens: 300,
                                                       temperature: 0.5
                                                     })

        payload = client.send(:build_request_payload,
                              prompt: 'Test prompt',
                              exception_message: exception_message,
                              app_stack: app_stack)

        payload[:model].should == 'claude-3'
        payload[:max_tokens].should == 300
        payload[:temperature].should == 0.5
        payload[:messages].should == [{ role: 'user', content: 'Test prompt' }]
      end
    end
  end
end
