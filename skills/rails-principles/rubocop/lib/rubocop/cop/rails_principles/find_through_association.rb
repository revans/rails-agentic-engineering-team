module RuboCop
  module Cop
    module RailsPrinciples
      # Look a record up through the association that owns it. `account.listings.find(id)` says what is being
      # accessed through what, and fails loudly (404) when the relationship is wrong; `Listing.find(params[:id])`
      # finds any listing in the table, so changing the id in a URL reaches a record that is not yours.
      #
      # Only lookups by id (or another key in `Keys`) whose arguments mention `params` are flagged. A lookup by
      # an email, a capability token or a slug has no owner to go through, so it is left alone.
      #
      # A model that nothing owns (an account or tenant, a bare top-level resource) has no association to go
      # through. List it under `AllowedModels` in .rubocop.yml, once, instead of disabling the cop at every lookup.
      #
      # @example
      #   # bad
      #   Listing.find(params[:id])
      #   Listing.find_by(id: params.expect(:id))
      #
      #   # good
      #   current_account.listings.find(params[:id])
      #   User.find_by(email_address: params[:email_address])
      #   Account.find(params[:id]) # with `AllowedModels: [Account]`
      class FindThroughAssociation < Base
        MSG = "Look `%<model>s` up through its owner (e.g. `current_account.%<association>s.%<method>s(...)`), not straight off the model. " \
              "If nothing owns `%<model>s`, list it under AllowedModels in .rubocop.yml."

        RESTRICT_ON_SEND = %i[find find_by find_by! find_sole_by].freeze

        def on_send(node)
          receiver = node.receiver
          return unless receiver&.const_type?
          return if allowed_model?(receiver)
          return unless looked_up_by_key_from_params?(node)

          add_offense(node, message: format(MSG, model: receiver.source, association: association_name(receiver), method: node.method_name))
        end

        private
          # `find(params[:id])` always looks up by id; `find_by(...)` only counts when the hash names a key we care about.
          def looked_up_by_key_from_params?(node)
            return node.arguments.any? { |argument| uses_params?(argument) } if node.method?(:find)

            node.arguments.any? { |argument| keyed_pair_from_params?(argument) }
          end

          def keyed_pair_from_params?(argument)
            return false unless argument.hash_type?

            argument.pairs.any? { |pair| (pair.key.sym_type? || pair.key.str_type?) && keys.include?(pair.key.value.to_s) && uses_params?(pair.value) }
          end

          def keys
            Array(cop_config["Keys"])
          end

          # `Account`, `Billing::Account` and `::Account` are written the same way in the config as in the code.
          def allowed_model?(constant)
            Array(cop_config["AllowedModels"]).map(&:to_s).include?(constant.source.delete_prefix("::"))
          end

          def uses_params?(node)
            node.each_node(:send).any? { |call| call.method?(:params) && call.receiver.nil? }
          end

          # A guess for the message only: Listing -> listings.
          def association_name(constant)
            name = constant.short_name.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
            name.end_with?("s") ? name : "#{name}s"
          end
      end
    end
  end
end
