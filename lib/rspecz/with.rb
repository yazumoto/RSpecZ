module RSpec
  module Core
    module MemoizedHelpers
      module ClassMethods
        class WithContext
          attr_accessor :name, :values, :description, :hint, :focused, :block, :myobject, :and_name, :and_block

          def initialize(name, values, block, myobject)
            @name, @values, @block, @myobject = name, values, block, myobject
          end

          def desc(description)
            @description = description
            self
          end

          def hint(text)
            @hint = text
          end

          def focused
            @focused = true
          end

          def and(name, &block)
            raise RuntimeError.new('You cannot set and two times! "and" method can use only one time in single with method.') unless @and_block.nil?
            @and_name = name
            @and_block = block
            self
          end

          def so(&block)
            root_context = @myobject.send(:root_context)
            so_count = root_context.metadata[RSpecZ::METADATA_SO_COUNT]
            root_context.metadata[RSpecZ::METADATA_SO_COUNT] = so_count == nil ? 1 : so_count + 1;

            continue_object = self
            continue_object_block = @block
            # TODO: create description from block.source
            if @values.length > 0
              raise RuntimeError.new("Syntax error you cannot set description by 'desc' method when you have multiple values set.") if @values.length > 1 && @description
              @values.each do |value|
                context_text = @hint ? "when #{@name} is #{@hint}(#{value})" : "when #{@name} is #{value}"

                spec_without_and = lambda do
                  let(continue_object.name) { value }
                  instance_exec(value, &block)
                end

                spec = @and_block.nil? ? spec_without_and : lambda do
                  context "and #{continue_object.and_name} is #{continue_object.__get_description(continue_object.and_block.source, 'and')}" do
                    let(continue_object.and_name) do
                      @super = lambda { super() } if defined? super
                      def _super
                        @super.call()
                      end
                      instance_eval(&continue_object.and_block)
                    end
                    instance_exec(&spec_without_and)
                  end
                end

                if @focused
                  @myobject.fcontext(context_text, &spec)
                else
                  @myobject.context(context_text, &spec)
                end
              end
            else
              context_text = @name ? "when #{@name} is #{__get_description(@block.source, 'with')}" : "prepare #{__get_description(@block.source, 'with')}"

              spec_without_and = lambda do
                if continue_object.name
                  let(continue_object.name) do
                    @super = lambda { super() } if defined? super
                    def _super
                      @super.call()
                    end
                    instance_eval(&continue_object_block)
                  end
                else
                  before { instance_eval(&continue_object_block) }
                end
                instance_exec(&block)
              end

              spec = @and_block.nil? ? spec_without_and : lambda do
                context "and #{continue_object.and_name} is #{continue_object.__get_description(continue_object.and_block.source, 'and')}" do
                  let(continue_object.and_name) { instance_eval(&continue_object.and_block) }
                  instance_exec(&spec_without_and)
                end
              end

              if @focused
                @myobject.fcontext(@description || context_text, &spec)
              else
                @myobject.context(@description || context_text, &spec)
              end
            end
          end

          # TODO: This method is temporary method. Need to implement proper logic in future .
          def __get_description(text, method_name)
            begin
              text = text[text.index("#{method_name}")..-1]
              bracket_start = text.index('{') || text.length
              do_start = text.index('do') || text.length

              start_word = bracket_start < do_start ? '{' : 'do'
              end_word = start_word == '{' ? '}' : 'end'

              start_index = [bracket_start, do_start].min + start_word.length
              inline_bracket_start = start_index
              next_end = 1
              start_word_count = 0

              loop do
                next_end = text[inline_bracket_start..-1].index(end_word) || text.length
                start_word_count += text[inline_bracket_start..inline_bracket_start+next_end].scan(start_word).length
                start_word_count -= 1
                # binding.pry
                break if start_word_count < 0
                inline_bracket_start += next_end + 1
              end

              text[start_index...inline_bracket_start+next_end].split("\n").last.strip
            rescue => e
              p 'Warning: rspecz with __get_description failed...'
              'different'
            end
          end
        end

        def with(name = nil, *values, &block) _with(name, nil, false, values, block); end
        def fwith(name = nil, *values, &block) _with(name, nil, true, values, block); end

        def with_valid(name = nil, *values, &block) _with(name, 'valid', false, values, block); end
        alias_method :with_valids, :with_valid

        def fwith_valid(name = nil, *values, &block) _with(name, 'valid', true, values, block); end
        alias_method :fwith_valids, :fwith_valid

        def with_invalid(name = nil, *values, &block) _with(name, 'invalid', false, values, block); end
        alias_method :with_invalids, :with_invalid

        def fwith_invalid(name = nil, *values, &block) _with(name, 'invalid', true, values, block); end
        alias_method :fwith_invalids, :fwith_invalid

        def with_missing(name = nil, *values, &block) _with(name, 'missing',false, values, block); end
        alias_method :with_missings, :with_missing

        def fwith_missing(name = nil, *values, &block) _with(name, 'missing',true, values, block); end
        alias_method :fwith_missings, :fwith_missing

        def with_nil(*names) _with_nil(names, false); end
        alias_method :with_nils, :with_nil

        def fwith_nil(*names) _with_nil(names, true); end
        alias_method :fwith_nils, :fwith_nil

        private

        def _with(name, hint, focused, values, block)
          count_up_with_count

          with_context = WithContext.new(name, values, block, self)
          with_context.hint(hint) if hint
          with_context.focused if focused
          with_context
        end

        def _with_nil(names, focused)
          raise RuntimeError.new("Argument Error. You should set names.") if names.nil? || names.length == 0
          count_up_with_count

          continue_object = { names: names, focused: focused, myobject: self }

          def continue_object.desc(text)
            raise RuntimeError.new("Error. You cannot use desc with with_nil method.")
          end

          def continue_object.so(&block)
            root_context = self[:myobject].send(:root_context)
            so_count = root_context.metadata[RSpecZ::METADATA_SO_COUNT]
            root_context.metadata[RSpecZ::METADATA_SO_COUNT] = so_count == nil ? 1 : so_count + 1;

            continue_object = self
            continue_object[:names].each do |name|
              spec = lambda do
                let(name) { nil }
                instance_exec(name, &block)
              end
              if continue_object[:focused]
                self[:myobject].fcontext("When #{name} is nil", &spec)
              else
                self[:myobject].context("When #{name} is nil", &spec)
              end
            end
          end
          continue_object
        end

        def count_up_with_count
          with_count = root_context.metadata[RSpecZ::METADATA_WITH_COUNT]
          root_context.metadata[RSpecZ::METADATA_WITH_COUNT] = with_count == nil ? 1 : with_count + 1
        end

        def root_context
          current = self
          # RSpec module describe how deep context is. So, minimum module class is the root context
          current.parent_groups.min do |a,b|
            a.ancestors.length <=> b.ancestors.length
          end
        end
      end
    end
  end
end
