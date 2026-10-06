module RuboCop
  module Cop
    module RailsPrinciples
      # Controllers expose only the seven REST actions. Anything else is a state change that deserves its own
      # nested singular resource controller (`Listings::SyncsController#create`, not `ListingsController#sync`),
      # or it is a helper and belongs under `private`.
      #
      # @example
      #   # bad
      #   class DocumentsController < ApplicationController
      #     def index; end
      #     def revoke; end
      #   end
      #
      #   # good
      #   class DocumentsController < ApplicationController
      #     def index; end
      #   end
      #
      #   class Documents::RevokesController < ApplicationController
      #     def create; end
      #   end
      class ControllerActions < Base
        MSG = "`%<name>s` is not one of the seven REST actions. Make it a nested singular resource controller " \
              "(e.g. `Documents::<Noun>Controller#create`), or make it private if it is not an action."

        VISIBILITY = %i[private protected public].freeze

        def on_class(node)
          return unless controller?(node)

          statements = body_statements(node)
          privatized = names_made_private_later(statements)
          visibility = :public

          statements.each do |statement|
            if (modifier = bare_visibility_modifier(statement))
              visibility = modifier
            elsif statement.def_type? && visibility == :public && !privatized.include?(statement.method_name)
              check(statement)
            end
          end
        end

        private
          def controller?(node)
            node.identifier.short_name.to_s.end_with?("Controller")
          end

          def body_statements(node)
            body = node.body
            return [] unless body

            body.begin_type? ? body.children : [ body ]
          end

          # `private` on a line by itself switches the visibility of everything after it.
          def bare_visibility_modifier(statement)
            return unless statement.send_type? && statement.receiver.nil? && statement.arguments.empty?

            statement.method_name if VISIBILITY.include?(statement.method_name)
          end

          # `private :foo, :bar` after the definitions.
          def names_made_private_later(statements)
            statements.flat_map do |statement|
              next [] unless statement.send_type? && statement.receiver.nil? && %i[private protected].include?(statement.method_name)

              statement.arguments.select { |argument| argument.sym_type? || argument.str_type? }.map { |argument| argument.value.to_sym }
            end
          end

          def check(definition)
            return if allowed_actions.include?(definition.method_name.to_s)

            add_offense(definition.loc.name, message: format(MSG, name: definition.method_name))
          end

          def allowed_actions
            Array(cop_config["AllowedActions"])
          end
      end
    end
  end
end
