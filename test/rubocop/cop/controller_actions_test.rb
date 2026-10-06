require "test_helper"

class ControllerActionsTest < Minitest::Test
  COP = RuboCop::Cop::RailsPrinciples::ControllerActions

  def test_flags_a_custom_public_action_and_names_it
    source = <<~RUBY
      class DocumentsController < ApplicationController
        def index; end

        def revoke
        end
      end
    RUBY

    assert_equal [ [ 4, "revoke" ] ], flagged(COP, source)
    assert_match(/`revoke` is not one of the seven REST actions/, messages(COP, source).first)
  end

  def test_the_seven_rest_actions_are_fine
    source = <<~RUBY
      class DocumentsController < ApplicationController
        def index; end
        def show; end
        def new; end
        def create; end
        def edit; end
        def update; end
        def destroy; end
      end
    RUBY

    assert_empty flagged(COP, source)
  end

  def test_private_and_protected_methods_are_fine_however_they_are_declared
    source = <<~RUBY
      class DocumentsController < ApplicationController
        def index; end

        def later_private; end
        def also_later; end
        private :later_private
        protected :also_later

        private def one_liner; end

        private
          def helper; end

        protected
          def other_helper; end
      end
    RUBY

    assert_empty flagged(COP, source)
  end

  def test_public_can_be_switched_back_on
    source = <<~RUBY
      class DocumentsController < ApplicationController
        private
          def helper; end

        public
          def sneaky; end
      end
    RUBY

    assert_equal [ [ 6, "sneaky" ] ], flagged(COP, source)
  end

  def test_a_class_in_a_namespace_is_still_a_controller
    source = <<~RUBY
      module Documents
        class RevokesController < ApplicationController
          def create; end
          def undo; end
        end
      end
    RUBY

    assert_equal [ [ 4, "undo" ] ], flagged(COP, source)
  end

  def test_class_methods_and_singleton_blocks_are_not_actions
    source = <<~RUBY
      class DocumentsController < ApplicationController
        def self.helper; end

        class << self
          def other; end
        end
      end
    RUBY

    assert_empty flagged(COP, source)
  end

  def test_classes_that_are_not_controllers_are_ignored
    assert_empty flagged(COP, "class Document < ApplicationRecord\n  def revoke; end\nend\n")
  end

  def test_only_looks_in_the_controllers_directory
    assert_empty flagged(COP, "class XController\n  def odd; end\nend\n", path: "app/models/x_controller.rb")
  end

  def test_the_allowed_actions_can_be_extended_per_project
    source = "class SessionsController < ApplicationController\n  def switch; end\nend\n"

    assert_equal [ [ 2, "switch" ] ], flagged(COP, source)
    assert_empty flagged(COP, source, config: { "AllowedActions" => %w[index show new create edit update destroy switch] })
  end

  def test_an_empty_controller_is_fine
    assert_empty flagged(COP, "class EmptyController < ApplicationController\nend\n")
  end
end
