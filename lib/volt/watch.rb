module Volt
  module Watch

    # Adds a watch for a change in an attribute of a Volt::Model.
    #
    # 'target' must be a Proc which returns the value of the attribute,
    # for example: `->{ person._name }`.
    #
    # When the attribute changes then the given block will be called.
    #
    # The new value of the attribute will be passed as an argument
    # to the block. The block is not required to define the argument.
    #
    # For example:
    #
    # ```
    #   watch ->{ person._name} do |name|
    #     puts name
    #   end
    # ```                                
    #
    # or
    #
    # ```
    #   watch ->{ person._name} do
    #     puts person._name
    #   end
    # ```
    def watch(target, &block)
      Volt.logger.debug "#{self.class.name}##{__method__}[#{__LINE__}] : setting basic watch on #{target} with no block = #{block}"
      add_watch(target, mode: :basic, action: block)
    end

    def reactive(target)
      Volt.logger.debug "#{self.class.name}##{__method__}[#{__LINE__}] : target => #{target}"
      add_watch(target, mode: :basic)
    end
    alias_method :activate, :reactive

    # Adds a watch for a change in the values of a Volt::Model,
    # Volt::ArrayMode, Volt::ReactiveArray or Volt::ReactiveHash.
    #
    # 'target' must be a Proc which returns the value of the model,
    # array or hash.
    #
    # When any value in the model, array or hash changes then
    # the given block will be called.
    #
    # The values of a Volt::Model are its attributes.
    #
    # The values of an Volt::ArrayModel are its elements.
    #
    # The values of an Volt::ReactiveHash are its key-value pairs.
    #
    # The attribute_name/index/key of the changed value will be
    # passed as the first argument to the given block. The new
    # associated value will be passed as the second argument.
    #
    # For example:
    #
    # ```
    #   watch_values ->{ user } do |attr, value|
    #     puts "user.#{attr} => #{value}"
    #   end
    # ```
    # or
    #
    # ```
    #   watch_values ->{ user } do |attr|
    #     puts "user.#{attr} => #{user.get(attr)}"
    #   end
    # ```
    # or
    #
    # ```
    #   watch_values ->{ page._items} do |index, value|
    #     puts "page[#{index}] => #{item}"
    #   end
    # ```
    # or
    #
    # ```
    #   watch_values ->{ page._items} do |index|
    #     puts "page[#{index}] => #{page._items[index]}"
    #   end
    # ```
    # or
    #
    # ```
    #   watch_values ->{ store.dictionary } do |key, entry|
    #     puts "dictionary[#{key}] => #{entry}"
    #   end
    # ```
    # or
    # ```
    #   watch_values ->{ store.dictionary } do |key|
    #     puts "dictionary[#{key}] => #{store.dictionary[key]}"
    #   end
    # ```
    def watch_values(target, &block)
      add_watch(target, mode: :values, action: block)
    end

    alias_method :when_shallow_change_in, :watch_values
    alias_method :on_shallow_change_in, :watch_values
    alias_method :on_change_in, :watch_values
    alias_method :when_change_in, :watch_values

    # Adds a watch for any change to the object returned by
    # 'root' and for any change to any object reachable from
    # the root.
    #
    # The root object may be a Volt::Model, Volt::ArrayModel,
    # Volt::ReactiveArray or Volt::ReactiveHash.
    #
    # 'root' must be a Proc which returns the model, array or hash.
    #
    # If the value of the root object or any reactive object reachable
    # from it changes then the given block will be called with the root
    # object as the argument.
    #
    # Note: use this method when you are watching for changes to the
    # 'contents' of a model/array/hash (and any reachable object) but
    # you DO NOT need to identify what in particular changed.
    #
    # For example:
    #
    # ```
    #   watch_any ->{ person } do
    #     puts "an attribute of #{person.name} has changed"
    #   end
    # ```
    #
    # Any optional array of attributes to ignore may be given.
    # The array should contain symbols matching model attributes
    # or hash keys which you wish to ignore changes to. It may
    # also include `:size` if you wish to ignore changes to the
    # size of reachable arrays or hashes.
    def watch_any(root, ignore: nil, &block)
      add_watch(root, mode: :any, ignore: ignore, action: block)
    end

    def when_deep_change_in(root, except: nil, &block)
      if block.arity <= 1
        add_watch(root, mode: :any, ignore: except, action: block)
      elsif block.arity <= 3
        add_watch(root, mode: :all, ignore: except, action: block)
      else
        raise ArgumentError, "watch_any_change_in block should expect either 0, 1, 2 or 3 arguments"
      end
    end

    alias_method :on_deep_change_in, :when_deep_change_in

    # Adds a watch for all changes to the object returned by
    # 'root' and for all change to any object reachable from
    # the root.
    #
    # The root object may be a Volt::Model, Volt::ArrayModel,
    # Volt::ReactiveArray or Volt::ReactiveHash.
    #
    # 'root' must be a Proc which returns the model, array or hash.
    #
    # If the root object or any reactive object (node) reachable
    # from it changes then the given block will be called with the
    # parent of the changed value as the first argument, the
    # attribute_name/index/key associated with the value as the
    # second argument, and the value (node) itself as the third argument.
    #
    # Additionally, for arrays and hashes, if the size of the array/hash
    # has changed the given block will be called with the
    # array/hash whose size has changed as the first argument, the
    # symbol `:size` as the second argument, and the new size of
    # the array/hash as as the third argument.
    #
    # Note: use this method when you are watching for changes to the
    # 'contents' of a model/array/hash (and any reachable object) and
    # you DO need to identify the particular value that changed.
    #
    # For example:
    #
    # ```
    #   class Contact < Volt::Model
    #     field :street
    #     field :city
    #     field :zip
    #     field :country
    #     field :phone
    #     field :email
    #   end
    #
    #   class Customer < Volt::Model
    #     field :name
    #     field :contact
    #   end
    #
    #   class Order < Volt::Model
    #     field :customer
    #     field :product
    #     field :date
    #     field :quantity
    #   end
    #
    #   def watch_orders
    #     watch_all ->{ orders } do |parent, tag, value|
    #       case
    #         when parent == orders
    #           if tag == :size
    #             puts "orders.size has changed to #{value}"
    #           else
    #             index = tag
    #             puts "orders[#{index}] has changed to #{orders[index]}"
    #           end
    #         when parent.is_a? Customer
    #           customer, attr = value, tag
    #           puts "customer #{customer.id} #{attr} has changed to #{customer.get(attr)}"
    #         when parent.is_a? Order
    #           order, attr = value, tag
    #           puts "order #{order.id} #{attr} has changed to #{order.get(attr)}"
    #       end
    #     end
    #   end
    # ```
    #
    # Any optional array specifying attributes you wish to ignore
    # may be given. The array should include symbols matching model
    # attributes or hash keys which you wish to ignore changes to.
    # It may also include `:size` if you wish to ignore changes
    # to the size of reachable arrays or hashes.
    def watch_all(root, ignore: nil, &block)
      add_watch(root, mode: :all, ignore: ignore, action: block)
    end

    # Stops and destroys all current watches.
    # Call when watches are no longer required.
    # Should typically be called when leaving a page,
    # for example in `before_{action}_remove`
    def stop_watches
      if @watches
        @watches.each do |b|
          b.stop
        end
        @watches = nil
      end
    end

    private

    def add_watch(target, mode: nil, ignore: nil, action: nil)
      raise ArgumentError, 'first argument must be a Proc' unless target.is_a?(Proc)
      # raise ArgumentError, 'no block given for watch' unless action
      @watches ||= []
      @watches << case mode
        when :basic
          if action
            -> do
              action.call(target.call)
            end.watch!
          else
            Volt.logger.debug "#{self.class.name}##{__method__}[#{__LINE__}] : setting basic watch on proc with no block"
            target.watch!
          end
        when :values, :any, :all
          traverse(target, mode, action)
        else
          raise ArgumentError, "unhandled watch mode #{mode.nil? ? 'nil' : mode}"
      end
    end

    def traverse(target, mode, block)
      proc = ->{ traverse_node(target.call, mode, 0, block) }
      mode == :any ? @watches << proc.watch! : proc.call
    end

    def traverse_node(node, mode, level, block)
      level += 1
      if node.is_a?(Volt::Model)
        traverse_model(node, mode, level, block)
      elsif node.is_a?(Volt::ReactiveArray)
        traverse_array(node, mode, level, block)
      elsif node.is_a?(Volt::ReactiveHash)
        traverse_hash(node, mode, level, block)
      end
    end

    def traverse_array(array, mode, level, block)
      compute_size(hash, mode, ignore, block)
      array.size.times do |i|
        # must access through array[i] to trigger dependency
        compute_value(array, i, ->{ array[i] }, mode, block)
      end
      unless mode == :values && level == 1
        array.size.times do |i|
          traverse_node(array[i], mode, level, block)
        end
      end
    end

    def traverse_hash(hash, mode, level, block)
      compute_size(hash, mode, ignore, block)
      hash.each_key do |key|
        # must access through hash[key] to trigger dependency
        compute_value(hash, key, ->{ hash[key] }, mode, block)
      end
      unless mode == :values && level == 1
        hash.each_value do |value|
          traverse_node(value, mode, level, block)
        end
      end
    end

    def traverse_model(model, mode, level, block)
      traverse_model_attrs(model, mode, level, block)
      traverse_model_fields(model, mode, level, block)
    end

    def traverse_model_attrs(model, mode, level, block)
      model.attributes.each_key do |attr|
        # must access through get(_attr) to trigger dependency
        _attr = :"_#{attr}"
        compute_value(model, _attr, ->{ model.get(_attr) }, mode, block)
      end
      unless mode == :values && level == 1
        model.attributes.each_key do |attr|
          traverse_node(model.get(:"_#{attr}"), mode, level, block)
        end
      end
    end

    def traverse_model_fields(model, mode, level, block)
      fields = model.class.fields_data
      if fields
        fields.each_key do |attr|
          # must access through send(attr) to trigger dependency
          compute_value(model, attr, ->{ model.send(attr) }, mode, block)
        end
        unless mode == :values && level == 1
          fields.each_key do |attr|
            traverse_node(model.send(attr), mode, level, block)
          end
        end
      end
    end

    def compute_value(parent, locus, value, mode, block)
      compute_term mode, ->{ block.call(parent, locus, value.call) }
    end

    def compute_size(collection, mode, ignore, block)
      unless ignore && ignore.include?(:size)
        compute_term mode, ->{ block.call(collection, :size, collection.size) }
      end
    end

    def compute_term(mode, proc)
      mode == :any ? proc.call : proc.watch!
    end

  end
end
