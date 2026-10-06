require "test_helper"

class ForbiddenGemsTest < Minitest::Test
  COP = RuboCop::Cop::RailsPrinciples::ForbiddenGems

  def gemfile(*lines)
    "source \"https://rubygems.org\"\n#{lines.join("\n")}\n"
  end

  def test_flags_each_forbidden_gem_with_what_to_use_instead
    {
      "redis" => /Solid/, "devise" => /authentication generator/, "rspec-rails" => /Minitest/, "factory_bot_rails" => /fixtures/,
      "sidekiq" => /Solid Queue/, "carrierwave" => /Active Storage/, "draper" => /helper/, "active_model_serializers" => /jbuilder/,
      "pg_search" => /native search/
    }.each do |name, reason|
      found = messages(COP, gemfile(%(gem "#{name}")), path: "Gemfile")

      assert_equal 1, found.size, name
      assert_match reason, found.first, name
    end
  end

  def test_flags_the_gem_inside_groups_and_with_options
    source = gemfile('group :test do', '  gem "rspec-rails", require: false', 'end')

    assert_equal [ [ 3, '"rspec-rails"' ] ], flagged(COP, source, path: "Gemfile")
  end

  def test_the_approved_stack_is_fine
    source = gemfile('gem "rails"', 'gem "solid_queue"', 'gem "propshaft"', 'gem "minitest"', 'gem "jbuilder"', 'gem "sqlite3"')

    assert_empty flagged(COP, source, path: "Gemfile")
  end

  def test_a_project_can_allow_one_gem_and_the_rest_stay_forbidden
    source = gemfile('gem "redis"', 'gem "sidekiq"')

    assert_equal [ [ 3, '"sidekiq"' ] ], flagged(COP, source, path: "Gemfile", config: { "Allowed" => [ "redis" ] })
  end

  def test_a_project_can_forbid_more
    source = gemfile('gem "faker"')

    assert_empty flagged(COP, source, path: "Gemfile")
    assert_equal 1, flagged(COP, source, path: "Gemfile", config: { "Forbidden" => { "faker" => "Use fixtures." } }).size
  end

  def test_only_looks_at_gemfiles
    assert_empty flagged(COP, 'gem "redis"', path: "app/models/thing.rb")
  end

  def test_a_gem_name_that_is_not_a_literal_is_ignored
    assert_empty flagged(COP, gemfile("gem name"), path: "Gemfile")
  end

  def test_other_methods_called_gem_on_a_receiver_are_ignored
    assert_empty flagged(COP, gemfile('spec.gem "redis"'), path: "Gemfile")
  end
end
