# coding: utf-8
config = File.expand_path('../config', __FILE__)
require "#{config}/version"

Gem::Specification.new do |spec|
  spec.name          = "origen_llm"
  spec.version       = OrigenLlm::VERSION
  spec.authors       = ["Priyavadan Kumar"]
  spec.email         = ["priyavadan@gmail.com"]
  spec.summary       = "This plugin enables a simple LLM connector for Origen"
  spec.homepage      = "http://origen-sdk.org/origen_llm"

  spec.required_ruby_version     = '>= 2'
  spec.required_rubygems_version = '>= 1.8.11'

  # Only the files that are hit by these wildcards will be included in the
  # packaged gem, the default should hit everything in most cases but this will
  # need to be added to if you have any custom directories
  spec.files         = Dir["lib/origen_llm.rb", "lib/origen_llm/**/*.rb", "templates/**/*", "config/**/*.rb",
                           "bin/*", "lib/tasks/**/*.rake", "pattern/**/*.rb", "program/**/*.rb",
                           "app/lib/**/*.rb", "app/templates/**/*",
                           "app/patterns/**/*.rb", "app/flows/**/*.rb", "app/blocks/**/*.rb"
                          ]
  spec.executables   = []
  spec.require_paths = ["lib", "app/lib"]

  # Add any gems that your plugin needs to run within a host application  
    
  # DO NOT ADD ANY ADDITIONAL RUNTIME DEPENDENCIES HERE, WHEN THESE GENERATORS
  # ARE INVOKED TO GENERATE A NEW APPLICATION IT WILL NOT BE LAUNCHED FROM WITHIN
  # A BUNDLED ENVIRONMENT.
  # 
  # THEREFORE GENERATORS MUST NOT RELY ON ANY 3RD PARTY GEMS THAT ARE NOT
  # PRESENT AS PART OF A STANDARD ORIGEN INSTALLATION - I.E. YOU CAN ONLY RELY
  # ON THE GEMS THAT ORIGEN ITSELF DEPENDS ON.
  end
