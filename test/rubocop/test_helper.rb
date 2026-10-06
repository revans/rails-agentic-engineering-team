require "minitest/autorun"
require "yaml"
require "pathname"
require "rubocop"

SKILL_RUBOCOP = Pathname.new(__dir__).join("../../skills/rails-principles/rubocop").expand_path
$LOAD_PATH.unshift SKILL_RUBOCOP.join("lib").to_s
require "rubocop-rails-principles"

# The defaults every test starts from: the same file an app inherits.
COP_DEFAULTS = YAML.safe_load_file(SKILL_RUBOCOP.join("config/default.yml")).freeze

# RuboCop's own cop-testing helper is built on RSpec, which this team does not use. This is the small part of it
# that matters: run one cop over a string of source and hand back the offenses (and the corrected source).
module CopTestHelper
  RUBY_VERSION_FOR_TESTS = 3.4

  def offenses_for(cop_class, source, path: "app/controllers/documents_controller.rb", config: {})
    investigate(cop_class, source, path, config).first
  end

  # [ [ line, highlighted source ], ... ] in line order, which is what most assertions want to compare.
  def flagged(cop_class, source, **options)
    offenses_for(cop_class, source, **options).sort_by(&:line).map { |offense| [ offense.line, offense.location.source ] }
  end

  def messages(cop_class, source, **options)
    offenses_for(cop_class, source, **options).sort_by(&:line).map(&:message)
  end

  private
    def investigate(cop_class, source, path, overrides)
      defaults = COP_DEFAULTS.fetch(cop_class.cop_name)
      config = RuboCop::Config.new({ cop_class.cop_name => defaults.merge("Enabled" => true).merge(overrides) }, "#{Dir.pwd}/.rubocop.yml")

      processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION_FOR_TESTS, "#{Dir.pwd}/#{path}", parser_engine: :parser_prism)
      raise "test source does not parse: #{processed_source.diagnostics.map(&:message).join(', ')}" unless processed_source.valid_syntax?

      processed_source.config = config
      processed_source.registry = RuboCop::Cop::Registry.new([ cop_class ])

      team = RuboCop::Cop::Team.new([ cop_class.new(config) ], config, raise_error: true)
      report = team.investigate(processed_source)
      [ report.offenses.reject(&:disabled?), report ]
    end
end

Minitest::Test.include CopTestHelper
