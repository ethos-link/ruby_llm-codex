# frozen_string_literal: true

require "ruby_llm"
require "ruby_llm/schema"
require_relative "ruby_llm/codex/version"
require_relative "ruby_llm/providers/codex"

unless RubyLLM::Provider.resolve(:codex)
  RubyLLM::Provider.register(:codex, RubyLLM::Providers::Codex)
end
