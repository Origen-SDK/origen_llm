# frozen_string_literal: true

module OrigenLlm
  # Module for building prompts for error analysis
  module ErrorAssistantPrompt
    module_function

    def build(exception_message:, app_stack:, mode: nil, site_template: nil)
      if mode.to_s == 'site_template' && !site_template.to_s.strip.empty?
        return site_template
               .gsub('%<exception_message>s', exception_message.to_s)
               .gsub('%<application_stack>s', Array(app_stack).join("\n"))
      end

      <<~PROMPT
        You are diagnosing an Origen application runtime failure.
        Return:
        1) Most likely root cause (1-2 sentences)
        2) Suggested fix steps (max 5 bullets)
        3) Confidence (low/medium/high)

        Exception:
        #{exception_message}

        Application stack:
        #{Array(app_stack).join("\n")}
      PROMPT
    end
  end
end
