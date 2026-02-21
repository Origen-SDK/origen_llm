# This file is used to hook the generators defined in this plugin into the
# 'origen new' command, it must not be removed or modified
require 'origen_app_generators'
require "origen_llm"
template_dir = File.expand_path('../../app/templates/app_generators', __FILE__)
OrigenAppGenerators.add_generators(OrigenLlm::AVAILABLE, template_dir: template_dir)
