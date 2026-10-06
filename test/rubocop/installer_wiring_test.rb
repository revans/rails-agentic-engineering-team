require "test_helper"
require "json"
require "open3"
require "tmpdir"
require "fileutils"

# The installer's `rubocop` step (bin/rails-team-setup-project): one inherit_from line in the app's .rubocop.yml.
# It runs the whole script, as /rails-install does, in a throwaway project and reads steps.rubocop from the JSON.
class InstallerWiringTest < Minitest::Test
  SCRIPT = Pathname.new(__dir__).join("../../bin/rails-team-setup-project").expand_path.to_s
  ENTRY = "./skills/rails-principles/rubocop/config/default.yml".freeze
  OMAKASE = <<~YAML.freeze
    # Omakase Ruby styling for Rails
    inherit_gem: { rubocop-rails-omakase: rubocop.yml }

    AllCops:
      # kept in sync with config/bootsnap.rb
      StringLiteralsFrozenByDefault: true
  YAML
  LOCKFILE = <<~LOCK.freeze
    GEM
      remote: https://rubygems.org/
      specs:
        rubocop (1.91.0)
        rubocop-rails (2.38.0)
  LOCK

  def setup
    @dir = Dir.mktmpdir("installer-wiring")
    vendored(true)
    File.write(File.join(@dir, "Gemfile.lock"), LOCKFILE)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def vendored(present)
    path = File.join(@dir, "skills/rails-principles/rubocop/config/default.yml")
    FileUtils.mkdir_p(File.dirname(path))
    present ? File.write(path, "# vendored\n") : FileUtils.rm_f(path)
  end

  def rubocop_yml = File.join(@dir, ".rubocop.yml")
  def write_config(text) = File.write(rubocop_yml, text)
  def config = File.read(rubocop_yml)
  def inherited = Array(YAML.safe_load(config)["inherit_from"])

  def run_step
    out, _err, _status = Open3.capture3("ruby", SCRIPT, "--dir", @dir)
    JSON.parse(out.lines.last).dig("steps", "rubocop")
  end

  def test_wires_an_omakase_config_by_adding_one_inherit_from_after_the_leading_comment
    write_config(OMAKASE)
    result = run_step

    assert_equal "ok", result["status"], result["detail"]
    assert_equal [ ENTRY ], inherited
    assert_equal OMAKASE.lines.first, config.lines.first, "the leading comment stays on top"
    assert_equal OMAKASE, config.sub(/inherit_from:\n  - #{Regexp.escape(ENTRY)}\n\n/, ""), "nothing else in the file changed"
  end

  def test_adds_to_an_existing_block_list_first_and_keeps_its_indentation
    write_config("inherit_from:\n    - .rubocop_todo.yml\n    - other.yml\nAllCops:\n  NewCops: enable\n")
    run_step

    assert_equal [ ENTRY, ".rubocop_todo.yml", "other.yml" ], inherited
    assert_includes config, "    - #{ENTRY}\n", "matches the 4-space indentation already used"
  end

  def test_turns_a_single_inherit_from_into_a_list
    write_config("inherit_from: .rubocop_todo.yml\nAllCops:\n  NewCops: enable\n")
    run_step

    assert_equal [ ENTRY, ".rubocop_todo.yml" ], inherited
    assert_equal "enable", YAML.safe_load(config).dig("AllCops", "NewCops")
  end

  def test_copes_with_a_comment_after_the_key
    write_config("inherit_from: # shared settings\n  - .rubocop_todo.yml\n")
    run_step

    assert_equal [ ENTRY, ".rubocop_todo.yml" ], inherited
  end

  def test_does_not_edit_an_inline_list_and_says_what_to_add
    original = "inherit_from: [ .rubocop_todo.yml, other.yml ]\n"
    write_config(original)
    result = run_step

    assert_equal "needs_input", result["status"]
    assert_includes result["detail"], ENTRY
    assert_equal original, config
  end

  def test_is_idempotent_and_leaves_the_file_alone_the_second_time
    write_config(OMAKASE)
    run_step
    wired = config
    second = run_step

    assert_equal "ok", second["status"]
    assert_match(/already wired/, second["detail"])
    assert_equal wired, config
    assert_equal 1, config.scan(ENTRY).size
  end

  def test_recognises_an_entry_written_without_the_leading_dot_slash
    write_config("inherit_from:\n  - skills/rails-principles/rubocop/config/default.yml\n")
    result = run_step

    assert_match(/already wired/, result["detail"])
    assert_equal 1, inherited.size
  end

  def test_asks_for_the_sync_first_when_the_cops_are_not_vendored_yet
    vendored(false)
    write_config(OMAKASE)
    result = run_step

    assert_equal "needs_input", result["status"]
    assert_match(%r{/rails-update}, result["detail"])
    assert_equal OMAKASE, config
  end

  def test_asks_for_a_rubocop_yml_rather_than_inventing_one
    result = run_step

    assert_equal "needs_input", result["status"]
    assert_match(/no \.rubocop\.yml/, result["detail"])
    refute File.exist?(rubocop_yml)
  end

  def test_asks_for_rubocop_rails_when_the_app_does_not_have_it
    write_config(OMAKASE)
    File.write(File.join(@dir, "Gemfile.lock"), "GEM\n  specs:\n    rubocop (1.91.0)\n")
    result = run_step

    assert_equal "needs_input", result["status"]
    assert_match(/rubocop-rails/, result["detail"])
    assert_equal OMAKASE, config
  end

  def test_asks_for_a_newer_rubocop_when_the_app_is_too_old_for_plugins
    write_config(OMAKASE)
    File.write(File.join(@dir, "Gemfile.lock"), "GEM\n  specs:\n    rubocop (1.60.0)\n    rubocop-rails (2.30.0)\n")

    assert_equal "needs_input", run_step["status"]
    assert_equal OMAKASE, config
  end

  def test_reports_a_config_that_does_not_parse_and_leaves_it_alone
    broken = "AllCops: [unclosed\n"
    write_config(broken)
    result = run_step

    assert_equal "failed", result["status"]
    assert_equal broken, config
  end

  def test_a_config_with_no_top_level_keys_is_wired
    write_config("# just a comment\n")
    run_step

    assert_equal [ ENTRY ], inherited
  end
end
