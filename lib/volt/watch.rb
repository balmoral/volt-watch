module Volt
  module Watch

    # Add reactivity to the given proc.
    #
    # The proc will be called if any reactive
    # attribute accessed in the proc changes.
    #
    # For example:
    #
    # ```
    #   activate ->{ puts person._name }
    # ```
    #
    # The behaviour is identical to doing
    #
    # ```
    #   ->{ puts person._name }.watch!
    # ```
    #
    # Alias is :watch
    def activate(proc)
      add_watch(proc)
    end
    alias_method :watch, :activate


    # Adds a watch for a shallow change in the contents
    # (attributes, elements, or key-value pairs) of a
    # Volt::Model, Volt::ArrayModel, Volt::ReactiveArray)
    # or Volt::ReactiveHash.
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
    def on_change_in(model, except: nil, &block)
      ensure_reactive(root)
      traverse(model, :shallow, except, block)
    end

    # Does a deep traversal of all values reachable from
    # the given root object.
    #
    # Such values include:
    #   * attributes and field values of Volt::Model's
    #   * size and elements of Volt::ArrayModel's
    #   * size and elements of Volt::ReactiveArray's
    #   * size and key-value pairs of Volt::ReactiveHash's
    #   * nested values of the above
    #
    # The root may be a Volt::Model, Volt::ArrayModel,
    # Volt::ReactiveArray or Volt::ReactiveHash.
    #
    # If the given block accepts zero or one argument then
    # a single watch will be created which results in the
    # block being called with the root object as the argument
    # whenever any change occurs at any depth. This mode is
    # suitable when watching for deep changes to the contents
    # of a model/array/hash but you DO NOT need to identify
    # the particular value that changed.
    #
    # If the given block accepts two or more arguments then
    # a watch will be created on each value reachable from
    # the root. The block will be called when any value changes
    # and will be passed three arguments:
    #   1. the parent (owner) of the value that changed
    #      i.e. the model, array or hash holding the value
    #   2. the locus of the value, either:
    #      * the attribute or field name for a model
    #      * the index in an array
    #      * the key in a hash
    #      * the symbol :size if array or hash size changes
    #   3. the new value
    # The block may choose to accept 2 or 3 arguments.
    # This mode is suitable when watching for deep changes
    # to the contents of a model/array/hash and you DO need
    # to identify what value that changed.
    #
    # In both modes, any optional argument specifying attributes
    # you don't want to watch may be given with the :except
    # keyword argument. The argument should be a symbol or
    # integer or array of symbols or integers matching model
    # attributes, array indexes or hash keys which you wish
    # to ignore changes to. It may also include `:size` if you
    # wish to ignore changes to the size of arrays or hashes.
    # TODO: make :except more precise, perhaps with pairs of
    # [parent, locus] to identify exceptions more accurately.
    # Also allow for [Class, locus] to except any object of
    # the given class.
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
    #   ...
    #
    #   def shallow_order_watch
    #     # one argument in given block has no detail of change
    #     on_deep_change_in orders do |store._orders|
    #       puts "something unknown changed in orders"
    #     end
    #   end
    #
    #   def deep_order_watch
    #     # three arguments in given block gives detail of change
    #     on_deep_change_in store._orders do |context, locus, value|
    #       case
    #         when context == store._orders
    #           if locus == :size
    #             puts "orders.size has changed to #{value}"
    #           else
    #             index = locus
    #             puts "orders[#{index}] has changed to #{value}"
    #           end
    #         when context.is_a? Order
    #           order, attr = context, locus
    #           puts "Order[#{order.id}].#{attr} has changed to #{value}"
    #         when context.is_a? Customer
    #           customer, attr = context, locus
    #           puts "customer #{customer.id} #{attr} has changed to #{value}"
    #       end
    #     end
    #   end
    # ```
    #
    def on_deep_change_in(root, except: nil, &block)
      ensure_reactive(root)
      if block.arity <= 1
        add_watch( ->{ traverse(root, :root, except, block) } )
      else
        traverse(root, :node, except, block)
      end
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

    def ensure_reactive(model)
      unless reactive?(model)
        raise ArgumentError, 'argument must be Volt Model, ArrayModel, ReactiveArray or ReactiveHash'
      end
    end

    def reactive?(model)
      Volt::Model === model ||
      Volt::ArrayModel === model ||
      Volt::ReactiveArray == model ||
      Vot::ReactiveHash === model
    end

    def traverse(node, mode, except, block)
      if node.is_a?(Volt::Model)
        traverse_model(node, mode, except, block)
      elsif node.is_a?(Volt::ReactiveArray)
        traverse_array(node, mode, except, block)
      elsif node.is_a?(Volt::ReactiveHash)
        traverse_hash(node, mode, except, block)
      end
    end

    def traverse_array(array, mode, except, block)
      compute_size(hash, mode, except, block)
      array.size.times do |i|
        # must access through array[i] to trigger dependency
        compute_value(array, i, ->{ array[i] }, mode, except, block)
      end
      unless mode == :shallow 
        array.size.times do |i|
          traverse(array[i], mode, except, block)
        end
      end
    end

    def traverse_hash(hash, mode, except, block)
      compute_size(hash, mode, except, block)
      hash.each_key do |key|
        # must access through hash[key] to trigger dependency
        compute_value(hash, key, ->{ hash[key] }, mode, except, block)
      end
      unless mode == :shallow
        hash.each_value do |value|
          traverse(value, mode, except, block)
        end
      end
    end

    def traverse_model(model, mode, except, block)
      traverse_model_attrs(model, mode, except, block)
      traverse_model_fields(model, mode, except, block)
    end

    def traverse_model_attrs(model, mode, except, block)
      model.attributes.each_key do |attr|
        # must access through get(attr) to trigger dependency
        compute_value(model, attr, ->{ model.get(attr) }, mode, except, block)
      end
      unless mode == :shallow
        model.attributes.each_key do |attr|
          traverse(model.get(:"#{attr}"), mode, except, block)
        end
      end
    end

    def traverse_model_fields(model, mode, except, block)
      fields = model.class.fields_data
      if fields
        fields.each_key do |attr|
          # must access through send(attr) to trigger dependency
          compute_value(model, attr, ->{ model.send(attr) }, mode, except, block)
        end
        unless mode == :shallow 
          fields.each_key do |attr|
            traverse(model.send(attr), mode, except, block)
          end
        end
      end
    end

    def compute_value(parent, locus, value, mode, except, block)
      unless except && except.include?(locus)
        compute_term mode, ->{ block.call(parent, locus, value.call) }
      end
    end

    def compute_size(collection, mode, except, block)
      unless except && except.include?(:size)
        compute_term mode, ->{ block.call(collection, :size, collection.size) }
      end
    end

    def compute_term(mode, proc)
      mode == :node ? add_watch(proc) : proc.call
    end

    def add_watch(proc)
      (@watches ||= []) << proc.watch!
    end

  end
end
