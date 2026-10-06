module RuboCop
  module Cop
    module RailsPrinciples
      # Gems the rails-principles skill rules out, each with what to use instead. The list lives in config
      # (`Forbidden`, name => reason) so a project can add to it; a gem a project genuinely needs goes under
      # `Allowed`, which is the one visible, reviewable place to say "this project is the exception".
      #
      # @example
      #   # bad
      #   gem "sidekiq"
      #
      #   # good
      #   gem "solid_queue"
      class ForbiddenGems < Base
        MSG = "Do not use `%<name>s`. %<reason>s"

        RESTRICT_ON_SEND = %i[gem].freeze

        def on_send(node)
          return unless node.receiver.nil?

          name_node = node.first_argument
          return unless name_node&.str_type?

          name = name_node.value
          reason = forbidden[name]
          return if reason.nil? || allowed.include?(name)

          add_offense(name_node, message: format(MSG, name: name, reason: reason))
        end

        private
          def forbidden
            cop_config["Forbidden"] || {}
          end

          def allowed
            Array(cop_config["Allowed"])
          end
      end
    end
  end
end
