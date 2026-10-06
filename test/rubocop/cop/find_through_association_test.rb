require "test_helper"

class FindThroughAssociationTest < Minitest::Test
  COP = RuboCop::Cop::RailsPrinciples::FindThroughAssociation

  def wrap(line)
    "class DocumentsController < ApplicationController\n  def show\n    #{line}\n  end\nend\n"
  end

  def test_flags_a_lookup_straight_off_the_model_with_params
    [
      "Document.find(params[:id])",
      "Document.find_by(id: params[:id])",
      "Document.find_by!(id: params[:id])",
      "Document.find_by(\"id\" => params[:id])",
      "Document.find(params.expect(:id))",
      "Document.find_by(id: params.expect(:id), status: :live)",
      "Document.find_sole_by(id: params[:id].to_s)"
    ].each do |line|
      assert_equal 1, flagged(COP, wrap(line)).size, line
    end
  end

  def test_the_message_suggests_going_through_the_owner
    message = messages(COP, wrap("Listing.find(params[:id])")).first

    assert_match(/Listing/, message)
    assert_match(/current_account\.listings\.find/, message)
  end

  def test_scoped_and_namespaced_models_are_flagged_too
    assert_equal 1, flagged(COP, wrap("Billing::Invoice.find(params[:id])")).size
  end

  def test_going_through_an_association_is_fine
    [
      "current_account.listings.find(params[:id])",
      "@account.listings.find_by!(id: params[:id])",
      "Document.available.find_by(share_token: params[:token])"
    ].each do |line|
      assert_empty flagged(COP, wrap(line)), line
    end
  end

  def test_lookups_by_something_other_than_id_have_no_owner_to_go_through
    [
      "User.find_by(email_address: params[:email_address])",
      "Document.find_by!(share_token: params[:token])",
      "Page.find_sole_by(slug: params[:slug])",
      "User.find_by_password_reset_token!(params[:token])"
    ].each do |line|
      assert_empty flagged(COP, wrap(line)), line
    end
  end

  def test_the_keys_can_be_extended_per_project
    line = "Document.find_by(public_id: params[:id])"

    assert_empty flagged(COP, wrap(line))
    assert_equal 1, flagged(COP, wrap(line), config: { "Keys" => %w[id public_id] }).size
  end

  def test_a_model_that_nothing_owns_can_be_allowed
    config = { "AllowedModels" => [ "Account" ] }

    [ "Account.find(params[:id])", "Account.find_by(id: params.expect(:id))", "::Account.find(params[:id])" ].each do |line|
      assert_empty flagged(COP, wrap(line), config: config), line
    end
  end

  def test_allowing_one_model_does_not_allow_the_others
    config = { "AllowedModels" => [ "Account" ] }

    assert_equal 1, flagged(COP, wrap("Listing.find(params[:id])"), config: config).size
    assert_equal 1, flagged(COP, wrap("Account.find(params[:id])"), config: { "AllowedModels" => [ "Billing::Account" ] }).size, "a namespaced name is not the same model"
  end

  def test_a_namespaced_model_is_allowed_by_its_full_name
    config = { "AllowedModels" => [ "Billing::Account" ] }

    assert_empty flagged(COP, wrap("Billing::Account.find(params[:id])"), config: config)
    assert_empty flagged(COP, wrap("::Billing::Account.find(params[:id])"), config: config)
  end

  def test_nothing_is_allowed_by_default
    assert_equal [], COP_DEFAULTS.fetch("RailsPrinciples/FindThroughAssociation").fetch("AllowedModels")
    assert_equal 1, flagged(COP, wrap("Account.find(params[:id])")).size
  end

  def test_the_message_points_at_the_option_for_models_nothing_owns
    assert_match(/list it under AllowedModels/, messages(COP, wrap("Account.find(params[:id])")).first)
  end

  def test_a_lookup_that_does_not_involve_params_is_fine
    [ "Document.find(1)", "Document.find(document_id)", "Setting.find_by(key: :theme)" ].each do |line|
      assert_empty flagged(COP, wrap(line)), line
    end
  end

  def test_only_looks_in_controllers
    assert_empty flagged(COP, "Document.find(params[:id])\n", path: "app/models/document.rb")
  end

  def test_a_receiver_that_is_not_a_constant_is_fine
    assert_empty flagged(COP, wrap("documents.find(params[:id])"))
  end
end
