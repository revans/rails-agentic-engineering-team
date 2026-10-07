require "test_helper"

# The cost/billing arithmetic. These are the parts of bin/agent-log where a silent error is
# expensive rather than merely annoying: a wrong apportionment misstates what a feature cost, and
# unlike a crash it looks exactly like a right one.
class CostTest < AgentLogTest
  OPUS_RATE = %w[billing rate --model claude-opus-5 --from 2020-01-01
                 --in 15 --out 75 --cache-write 18.75 --cache-read 1.50].freeze

  def plan!(seat: 125, included: 1000)
    run_log!("billing", "plan", "--name", "Test seat", "--seat-cost", seat, "--included", included, "--cycle-day", 1)
  end

  # The property that makes BilledUSD trustworthy: every dollar actually paid is attributed to
  # exactly one feature, and no dollar is invented. If this drifts, per-feature costs silently
  # stop summing to the invoice and nothing else in the tool would notice.
  def test_billed_column_sums_to_exactly_what_was_paid
    run_log!(*OPUS_RATE)
    seed_run(feature: "F-001", started: "2026-03-10", cache_read: 100_000_000)
    seed_run(feature: "F-002", started: "2026-03-20", cache_read: 300_000_000)
    plan!(seat: 125)

    row = run_log!("query", "cost").lines.find { |l| l.start_with?("ALL") }
    refute_nil row, "cost output has no ALL total row"
    billed = row.scan(/\$[\d.]+/).last

    assert_equal "$125.00", billed,
      "one period at $125 was paid, so the apportioned column must sum to $125 — got #{billed}"
  end

  # The 3:1 split is the point: apportionment is by token value, not by run count. Two runs in one
  # period, one consuming three times the other, must split the seat 75/25 and not 50/50.
  def test_apportionment_is_weighted_by_token_value_not_run_count
    run_log!(*OPUS_RATE)
    seed_run(feature: "F-001", started: "2026-03-10", cache_read: 100_000_000)
    seed_run(feature: "F-002", started: "2026-03-20", cache_read: 300_000_000)
    plan!(seat: 100)

    out = run_log!("query", "cost")
    f1 = out.lines.find { |l| l.start_with?("F-001") }.scan(/\$[\d.]+/).last
    f2 = out.lines.find { |l| l.start_with?("F-002") }.scan(/\$[\d.]+/).last

    assert_equal "$25.00", f1
    assert_equal "$75.00", f2
  end

  # A rate card is dated so an old run keeps costing what it cost. A single flat rate would
  # retroactively reprice finished work every time pricing changed.
  def test_a_run_is_priced_at_the_rate_in_force_on_its_own_date
    run_log!("billing", "rate", "--model", "claude-opus-5", "--from", "2020-01-01",
             "--in", 0, "--out", 0, "--cache-write", 0, "--cache-read", 1.0)
    run_log!("billing", "rate", "--model", "claude-opus-5", "--from", "2026-06-01",
             "--in", 0, "--out", 0, "--cache-write", 0, "--cache-read", 10.0)
    seed_run(feature: "F-OLD", started: "2026-03-10", cache_read: 1_000_000)
    seed_run(feature: "F-NEW", started: "2026-07-10", cache_read: 1_000_000)
    plan!

    out = run_log!("query", "cost")
    assert_match(/^F-OLD.*\$1\.00/,  out, "a pre-increase run must keep the old rate")
    assert_match(/^F-NEW.*\$10\.00/, out, "a post-increase run must use the new rate")
  end

  # Pricing an unknown model at some other model's rate would produce a confident wrong number.
  # Counting it as zero is also wrong, but it is VISIBLY wrong, which is the difference.
  def test_a_model_with_no_rate_row_is_reported_not_silently_priced
    run_log!(*OPUS_RATE)
    seed_run(feature: "F-001", started: "2026-03-10", model: "some-unpriced-model", cache_read: 999_000_000)
    plan!

    out = run_log!("query", "cost")
    assert_match(/NOT PRICED/, out)
    assert_match(/some-unpriced-model/, out)
  end

  # A period holding runs we cannot see is not a period of zero spend. Rendering the two the same
  # way understates what the seat bought and reads as a measured underspend.
  def test_a_period_with_runs_but_no_usage_says_so_instead_of_reporting_zero
    run_log!(*OPUS_RATE)
    id = run_log!("run", "start", "--agent-name", "engineer", "--feature-id", "F-001").strip
    sqlite("UPDATE runs SET started_at='2026-03-10T12:00:00' WHERE id='#{id}';")
    plan!

    out = run_log!("query", "billing")
    assert_match(/NO USAGE DATA/, out)
    refute_match(/0% of the/, out, "a period with no data must never render as 0% of allowance")
  end

  # Coverage below 100% makes every consumption figure a floor. Printing it without that caveat
  # invites reading a partial measurement as a total.
  def test_a_partially_measured_period_reports_its_coverage
    run_log!(*OPUS_RATE)
    seed_run(feature: "F-001", started: "2026-03-10", cache_read: 10_000_000)
    unmeasured = run_log!("run", "start", "--agent-name", "engineer", "--feature-id", "F-001").strip
    sqlite("UPDATE runs SET started_at='2026-03-11T12:00:00' WHERE id='#{unmeasured}';")
    plan!

    out = run_log!("query", "billing")
    assert_match(%r{coverage\s+1/2 runs measured \(50%\)}, out)
    assert_match(/the true figure is higher/, out)
  end

  # Re-running after a price change must update the periods in place. Doubling them would double
  # every apportioned cost, and the overage came off an invoice — it cannot be re-derived, so a
  # regeneration that discarded it would lose the only figure here that isn't an estimate.
  def test_regenerating_periods_updates_in_place_and_preserves_a_hand_entered_overage
    run_log!(*OPUS_RATE)
    seed_run(feature: "F-001", started: "2026-03-10", cache_read: 10_000_000)
    plan!(seat: 125)
    sqlite("UPDATE billing_periods SET overage_usd=42.0;")

    before = sqlite("SELECT COUNT(*) FROM billing_periods;").strip
    plan!(seat: 200)
    after = sqlite("SELECT COUNT(*) FROM billing_periods;").strip

    assert_equal before, after, "regenerating must not create duplicate periods"
    assert_equal "200.0", sqlite("SELECT seat_cost_usd FROM billing_periods;").strip
    assert_equal "42.0",  sqlite("SELECT overage_usd FROM billing_periods;").strip,
      "an invoice-sourced overage must survive regeneration"
  end

  # billing setup is interactive by design; a non-tty caller must get the scriptable command
  # rather than a hang or a half-written plan.
  def test_setup_refuses_non_interactively_and_names_the_scriptable_alternative
    _out, err, ok = run_log("billing", "setup")
    refute ok
    assert_match(/billing plan/, err)
  end
end
