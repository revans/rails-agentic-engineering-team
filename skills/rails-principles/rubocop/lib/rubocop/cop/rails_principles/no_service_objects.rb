module RuboCop
  module Cop
    module RailsPrinciples
      # Service objects, decorators, presenters and form objects pull logic away from the model that owns the
      # data and send the next reader file-jumping. Put the behavior on the model, as methods grouped into concerns.
      #
      # Three signs are checked, all of them cheap and exact:
      #
      # 1. A class or module named `...Service`, `...Presenter`, `...Decorator` and so on.
      # 2. A file under `app/services`, `app/decorators`, `app/presenters`, ...
      # 3. A plain class or module whose entry point is `call` / `perform` / `execute` / `run`: the shape of
      #    a service object whatever it is called. Classes that inherit from something (a job, a mailer, a
      #    record) are left alone.
      #
      # @example
      #   # bad
      #   class PublishDocumentService
      #     def self.call(document) = ...
      #   end
      #
      #   # good
      #   class Document < ApplicationRecord
      #     def publish! = ...
      #   end
      class NoServiceObjects < Base
        SUFFIX_MSG = "`%<name>s` looks like a service object (`%<suffix>s`). Put this behavior on the model that owns the data, as a method or a concern."
        DIRECTORY_MSG = "`%<directory>s` holds service-style objects. Put this behavior on the models that own the data, as methods and concerns."
        SHAPE_MSG = "`%<name>s` has a `%<method>s` entry point, the shape of a service object. Put this behavior on the model that owns the data, as a method or a concern."

        def on_new_investigation
          directory = forbidden_directory
          return unless directory && processed_source.ast

          add_offense(processed_source.ast.source_range.begin, message: format(DIRECTORY_MSG, directory: directory))
        end

        def on_class(node)
          check_name(node)
          check_shape(node) unless node.parent_class
        end

        def on_module(node)
          check_name(node)
          check_shape(node)
        end

        private
          def check_name(node)
            name = node.identifier.short_name.to_s
            suffix = Array(cop_config["ForbiddenSuffixes"]).find { |candidate| name.end_with?(candidate) }
            return unless suffix

            add_offense(node.identifier, message: format(SUFFIX_MSG, name: name, suffix: suffix))
          end

          def check_shape(node)
            entry = entry_point(node)
            return unless entry

            add_offense(node.identifier, message: format(SHAPE_MSG, name: node.identifier.short_name, method: entry))
          end

          # The name of the first `call`-style method defined directly on the class or module (instance, `self.`, or inside `class << self`).
          def entry_point(node)
            return unless node.body

            names = Array(cop_config["EntryPointMethods"]).map(&:to_sym)
            statements = node.body.begin_type? ? node.body.children : [ node.body ]
            statements.each do |statement|
              found = case statement.type
              when :def, :defs then statement.method_name
              when :sclass then singleton_entry_point(statement, names)
              end
              return found if found && names.include?(found)
            end
            nil
          end

          def singleton_entry_point(node, names)
            return unless node.body

            statements = node.body.begin_type? ? node.body.children : [ node.body ]
            statements.find { |statement| statement.def_type? && names.include?(statement.method_name) }&.method_name
          end

          def forbidden_directory
            path = processed_source.file_path.to_s
            Array(cop_config["ForbiddenDirectories"]).find { |directory| path.include?("/#{directory}/") || path.start_with?("#{directory}/") }
          end
      end
    end
  end
end
