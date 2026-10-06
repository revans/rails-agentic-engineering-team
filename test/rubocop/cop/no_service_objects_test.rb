require "test_helper"

class NoServiceObjectsTest < Minitest::Test
  COP = RuboCop::Cop::RailsPrinciples::NoServiceObjects

  def test_flags_a_forbidden_suffix_on_a_class_or_module
    {
      "class PublishDocumentService\nend\n" => "PublishDocumentService",
      "class ListingPresenter\nend\n" => "ListingPresenter",
      "class ListingDecorator\nend\n" => "ListingDecorator",
      "class SignupForm\nend\n" => "SignupForm",
      "class SignupFormObject\nend\n" => "SignupFormObject",
      "class ImportInteractor\nend\n" => "ImportInteractor",
      "class CreateOrderUseCase\nend\n" => "CreateOrderUseCase",
      "module TagServices\nend\n" => nil
    }.each do |source, name|
      found = flagged(COP, source, path: "app/models/thing.rb").map(&:last)
      name ? assert_equal([ name ], found, source) : assert_empty(found, source)
    end
  end

  def test_names_that_only_contain_a_suffix_word_are_fine
    [ "class Transform\nend\n", "class Platform\nend\n", "class ServiceArea < ApplicationRecord\nend\n", "class Informant\nend\n" ].each do |source|
      assert_empty flagged(COP, source, path: "app/models/thing.rb"), source
    end
  end

  def test_flags_a_file_inside_a_forbidden_directory
    source = "class Importer\n  def import; end\nend\n"

    assert_equal 1, flagged(COP, source, path: "app/services/importer.rb").size
    assert_match(%r{app/services}, messages(COP, source, path: "app/services/importer.rb").first)
    assert_empty flagged(COP, source, path: "app/models/importer.rb")
  end

  def test_flags_the_call_shaped_entry_point_on_a_plain_class
    {
      "class DocumentIntake\n  def self.call(html)\n  end\nend\n" => "DocumentIntake",
      "class DocumentIntake\n  def call; end\nend\n" => "DocumentIntake",
      "class DocumentIntake\n  class << self\n    def call(html); end\n  end\nend\n" => "DocumentIntake",
      "class Importer\n  def perform; end\nend\n" => "Importer",
      "class Importer\n  def execute; end\nend\n" => "Importer",
      "class Importer\n  def run; end\nend\n" => "Importer",
      "module Scanner\n  def self.call(html); end\nend\n" => "Scanner"
    }.each do |source, name|
      assert_equal [ name ], flagged(COP, source, path: "app/models/thing.rb").map(&:last), source
    end
  end

  def test_a_class_that_inherits_is_not_judged_by_its_entry_point
    [
      "class ImportJob < ApplicationJob\n  def perform(id); end\nend\n",
      "class Document < ApplicationRecord\n  def call; end\nend\n",
      "class Handler < Struct.new(:x)\n  def call; end\nend\n"
    ].each do |source|
      assert_empty flagged(COP, source, path: "app/models/thing.rb"), source
    end
  end

  def test_a_model_with_ordinary_methods_is_fine
    source = "class Document\n  def publish!; end\n  def revoke!; end\n  def runner; end\nend\n"

    assert_empty flagged(COP, source, path: "app/models/document.rb")
  end

  def test_jobs_mailers_and_controllers_are_excluded_by_default
    source = "class ImportJob\n  def perform(id); end\nend\n"

    assert_empty flagged(COP, source, path: "app/jobs/import_job.rb")
    assert_empty flagged(COP, "class WelcomeMailer\n  def call; end\nend\n", path: "app/mailers/welcome_mailer.rb")
  end

  def test_the_lists_can_be_changed_per_project
    assert_empty flagged(COP, "class PublishService\nend\n", path: "app/models/x.rb", config: { "ForbiddenSuffixes" => [ "Presenter" ] })
    assert_equal 1, flagged(COP, "class Importer\n  def process; end\nend\n", path: "app/models/x.rb", config: { "EntryPointMethods" => [ "process" ] }).size
  end
end
