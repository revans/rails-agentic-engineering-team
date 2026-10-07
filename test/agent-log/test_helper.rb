require "minitest/autorun"
require "open3"
require "tmpdir"
require "pathname"

# These tests run the real bin/agent-log as a subprocess against a throwaway database, the same
# way installer_wiring_test.rb runs the real installer against a throwaway project. There is no
# library to require — the tool is a single script with no test seam, so the only honest way to
# test it is to invoke it as its callers do.
class AgentLogTest < Minitest::Test
  SCRIPT = Pathname.new(__dir__).join("../../bin/agent-log").expand_path.to_s

  def setup
    @dir = Dir.mktmpdir("agent-log-test")
    @db  = File.join(@dir, "agent_log.sqlite3")
  end

  def teardown
    FileUtils.remove_entry(@dir) if @dir && Dir.exist?(@dir)
  end

  # Returns [stdout, stderr, success?]. Never raises on a nonzero exit — several tests assert on
  # the failure path, and a helper that raised would make those unwritable.
  def run_log(*args)
    out, err, status = Open3.capture3({ "AGENT_LOG_DB" => @db }, "ruby", SCRIPT, *args.map(&:to_s))
    [ out, err, status.success? ]
  end

  def run_log!(*args)
    out, err, ok = run_log(*args)
    flunk "bin/agent-log #{args.join(' ')} failed:\n#{err}#{out}" unless ok
    out
  end

  # A closed run with usage already reconciled, so the cost/billing maths has something to read
  # without needing a transcript on disk.
  def seed_run(feature:, started:, model: "claude-opus-5", cache_read: 0, cache_write: 0, t_in: 0, t_out: 0)
    id = run_log!("run", "start", "--agent-name", "engineer", "--feature-id", feature).strip
    sqlite(<<~SQL)
      UPDATE runs SET started_at='#{started}T12:00:00',
        tokens_in=#{t_in}, tokens_out=#{t_out},
        cache_creation_tokens=#{cache_write}, cache_read_tokens=#{cache_read},
        model='#{model}', usage_source='transcript'
      WHERE id='#{id}';
    SQL
    id
  end

  def sqlite(sql)
    out, err, status = Open3.capture3("sqlite3", @db, sql)
    flunk "sqlite3 failed: #{err}" unless status.success?
    out
  end
end
