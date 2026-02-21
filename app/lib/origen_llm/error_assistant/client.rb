require 'json'
require 'net/http'
require 'uri'

module OrigenLlm
  class ErrorAssistantClient
    DEFAULT_AUTH_MODE = 'x_api_key'
    DEFAULT_PROVIDER_MODE = 'generic'
    DEFAULT_MAX_TOKENS = 200
    DEFAULT_TEMPERATURE = 0.2
    DEFAULT_TIMEOUT = 3.0

    def initialize(context:)
      @api_url = context[:api_url]
      @provider_mode = (context[:provider_mode] || DEFAULT_PROVIDER_MODE).to_s
      @model = context[:model]
      @max_tokens = coerce_integer(context[:max_tokens], DEFAULT_MAX_TOKENS)
      @temperature = coerce_float(context[:temperature], DEFAULT_TEMPERATURE)
      @api_key_env = context[:api_key_env]
      @auth_mode = (context[:auth_mode] || DEFAULT_AUTH_MODE).to_s
      @auth_header_name = context[:auth_header_name]
      @auth_prefix = context[:auth_prefix]
      @extra_headers = context[:extra_headers].is_a?(Hash) ? context[:extra_headers] : {}
      @prompt_mode = (context[:prompt_mode] || 'default').to_s
      @backend_profile = context[:backend_profile]
      @backend_context = context[:backend_context].is_a?(Hash) ? context[:backend_context] : {}
      @timeout = coerce_float(context[:timeout_seconds], DEFAULT_TIMEOUT)
    end

    def analyze(prompt:, exception_message:, app_stack:)
      return nil if @api_url.to_s.strip.empty?
      return nil if anthropic_mode? && @model.to_s.strip.empty?

      uri = request_uri
      req = Net::HTTP::Post.new(uri)
      req['Content-Type'] = 'application/json'
      build_headers.each { |k, v| req[k] = v }
      req.body = JSON.dump(build_request_payload(
                             prompt:            prompt,
                             exception_message: exception_message,
                             app_stack:         app_stack
                           ))

      res = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl:      uri.scheme == 'https',
        open_timeout: @timeout,
        read_timeout: @timeout
      ) do |http|
        http.request(req)
      end

      return nil unless res.is_a?(Net::HTTPSuccess)

      parsed = begin
        JSON.parse(res.body)
      rescue
        {}
      end
      extract_answer(parsed)
    end

    private

    def secret
      return nil if @api_key_env.to_s.strip.empty?

      ENV[@api_key_env]
    end

    def build_headers
      headers = {}
      key = secret

      case @auth_mode
      when 'none'
        # No auth header
      when 'x_api_key'
        header_name = @auth_header_name.to_s.strip.empty? ? 'X-API-Key' : @auth_header_name
        headers[header_name] = key if key && !key.empty?
      when 'bearer'
        header_name = @auth_header_name.to_s.strip.empty? ? 'Authorization' : @auth_header_name
        prefix = @auth_prefix.nil? ? 'Bearer ' : @auth_prefix
        headers[header_name] = "#{prefix}#{key}" if key && !key.empty?
      when 'ocp_apim_subscription_key'
        header_name = @auth_header_name.to_s.strip.empty? ? 'Ocp-Apim-Subscription-Key' : @auth_header_name
        headers[header_name] = key if key && !key.empty?
      else
        header_name = @auth_header_name.to_s.strip.empty? ? 'X-API-Key' : @auth_header_name
        headers[header_name] = key if key && !key.empty?
      end

      @extra_headers.each do |k, v|
        headers[k.to_s] = v.to_s
      end
      headers
    end

    def build_request_payload(prompt:, exception_message:, app_stack:)
      if anthropic_mode?
        {
          model:       @model,
          max_tokens:  @max_tokens,
          temperature: @temperature,
          messages:    [{ role: 'user', content: prompt }]
        }
      else
        payload = {
          question: prompt,
          context:  {
            exception_message: exception_message,
            application_stack: Array(app_stack)
          }
        }
        payload[:model] = @model unless @model.to_s.strip.empty?

        if @prompt_mode == 'backend_profile' && !@backend_profile.to_s.strip.empty?
          payload[:profile_id] = @backend_profile
          payload[:backend_context] = @backend_context unless @backend_context.empty?
        end
        payload
      end
    end

    def request_uri
      uri = URI.parse(@api_url)
      return uri unless anthropic_mode?

      if uri.path.to_s.empty? || uri.path == '/'
        uri.path = '/v1/messages'
      elsif !uri.path.end_with?('/v1/messages')
        uri.path = "#{uri.path.sub(%r{/$}, '')}/v1/messages"
      end
      uri
    end

    def extract_answer(parsed)
      if anthropic_mode?
        content = parsed['content']
        if content.is_a?(Array)
          text_parts = content.select { |c| c.is_a?(Hash) && c['type'] == 'text' }.map { |c| c['text'].to_s }
          answer = text_parts.join("\n").strip
          return answer unless answer.empty?
        end
      end

      parsed['answer'] || parsed['suggestion'] || parsed['output'] || parsed['text']
    end

    def anthropic_mode?
      @provider_mode == 'anthropic_messages'
    end

    def coerce_integer(value, default_value)
      Integer(value)
    rescue
      default_value
    end

    def coerce_float(value, default_value)
      Float(value)
    rescue
      default_value
    end
  end
end
