require_relative 'error_assistant/client'
require_relative 'error_assistant/prompt'

module OrigenLlm
  module ErrorAssistant
    module_function

    def analyze(exception_message:, app_stack:, context: {})
      prompt = OrigenLlm::ErrorAssistantPrompt.build(
        exception_message: exception_message,
        app_stack:         app_stack,
        mode:              context[:prompt_mode],
        site_template:     context[:prompt_template]
      )

      response = OrigenLlm::ErrorAssistantClient.new(context: context).analyze(
        prompt:            prompt,
        exception_message: exception_message,
        app_stack:         app_stack
      )

      normalize_response(response)
    end

    def normalize_response(response)
      return nil if response.nil?

      text = response.to_s.strip
      return nil if text.empty?

      text
    end
  end
end
