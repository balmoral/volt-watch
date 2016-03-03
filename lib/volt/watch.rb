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
    #   watch do
    #     puts person._name
    #   end
    # ```
    #
    # The behaviour is identical to doing
    #
    # ```
    #   ->{ puts person._name }.watch!
    # ```
    #
    def watch(proc = nil, &block)
      add_watch(proc || block)
    end


    # Adds a watch for a shallow change in the contents
    # (attributes, elements, or key-value pairs) of one or
    # more reactive objects.
    #
    # Reactive objects are any of:
    #   Volt::Model
    #   Volt::ArrayModel
    #   Volt::ReactiveArray
    #   Volt::ReactiveHash
    #
    # When any value in the model, array or hash changes then
    # the given block will be called.
    #
    # The values of a Volt::Model are its attributes.
    #
    # The values of a Volt::ArrayModel or Volt::ReactiveArray are its elements.
    #
    # The values of an Volt::ReactiveHash are its key-value pairs.
    #
    # If the args contain more than one object or the arity of the
    # block, then the block will be passed the object, the
    # locus and the value. If only one object is given and the
    # block arity is less than 3, then the locus and the value
    # will be passed to the block.
    #
    # The locus is:
    #   the field name for a Volt::Model
    #   the integer index or :size for a Volt::ArrayModel
    #   the integer index or :size for a Volt::ReactiveArray
    #   the key for Volt::ReactiveHash
    #
    # For example:
    #
    # ```
    #   on_change_in(user) do |object, attr, value|
    #     puts "#{object}.#{attr} => #{value}"
    #   end
    # ```
    # or
    #
    # ```
    #   on_change_in(user) do |attr|
    #     puts "user.#{attr} => #{user.get(attr)}"
    #   end
    # ```
    # or
    #
    # ```
    #   on_change_in(page._items) do |index, value|
    #     puts "page[#{index}] => #{item}"
    #   end
    # ```
    # or
    #
    # ```
    #   on_change_in(page._items) do |index|
    #     puts "page[#{index}] => #{page._items[index]}"
    #   end
    # ```
    # or
    #
    # ```
    #   on_change_in(store.dictionary) do |key, entry|
    #     puts "dictionary[#{key}] => #{entry}"
    #   end
    # ```
    # or
    # ```
    #   on_change_in(store.dictionary) do |key|
    #     puts "dictionary[#{key}] => #{store.dictionary[key]}"
    #   end
    # ```
    def on_change_in(*args, except: nil, &block)
      args.each do |arg|
        ensure_reactive(arg)
        traverse(arg, :shallow, except, args.size > 1 || block.arity == 3, block)
      end
    end

    # Does a deep traversal of all values reachable from
    # the given root object(s).
    #
    # Such values include:
    #   * attributes and field values of Volt::Model's
    #   * size and elements of Volt::ArrayModel's
    #   * size and elements of Volt::ReactiveArray's
    #   * size and key-value pairs of Volt::ReactiveHash's
    #   * nested values of the above
    #
    # The root(s) may be a Volt::Model, Volt::ArrayModel,
    # Volt::ReactiveArray or Volt::ReactiveHash.
    #
    # The given block may accept one, two or three arguments.
    #
    # The block will be called when any value reachable from
    # (one of) the root(s) changes.
    #   1. the model (owner) of the value that changed
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
    # In both modes, an optional argument specifying attributes
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
    #   def deep_order_watch
    #     # one argument in given block has no detail of change
    #     on_deep_change_in orders do |store._orders|
    #       puts "something unknown changed in orders"
    #     end
    #   end
    #
    #   def on_deep_change_in
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
    def on_deep_change_in(*roots, except: nil, &block)
      roots.each do |root|
        ensure_reactive(root)
        traverse(root, :node, except, true, block)
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
        raise ArgumentError, 'argument must be Volt Model, ArrayModel, ReactiveArray or ReactiveHash...'
      end
    end

    def reactive?(model)
      reactive_model?(model) ||
      reactive_array?(model) ||
      reactive_hash?(model)
    end

    # Must behave like a Volt::Model
    # and respond to #get(attribute)
    def reactive_model?(model)
      Volt::Model === model ||
      # dirty way of letting anything be reactive if it wants
      (model.respond_to?(:reactive_model?) && model.reactive_model?) ||
      (model.class.respond_to?(:reactive_model?) && model.class.reactive_model?)
    end

    # Must behave like a Volt::ArrayModel or Volt::ReactiveArray
    def reactive_array?(model)
      Volt::ArrayModel === model ||
      Volt::ReactiveArray === model ||
      # dirty way of letting anything be reactive if it wants
      (model.respond_to?(:reactive_array?) && model.reactive_array?) ||
      (model.class.respond_to?(:reactive_array?) && model.class.reactive_array?)
    end

    # Must behave like a Volt::ReactiveHash
    def reactive_hash?(model)
      Volt::ReactiveHash === model ||
      # dirty way of letting anything be reactive if it wants
      (model.respond_to?(:reactive_hash?) && model.reactive_hash?) ||
      (model.class.respond_to?(:reactive_hash?) && model.class.reactive_hash?)
    end

    def traverse(node, mode, except, pass_model, block)
      # debug __method__, __LINE__, "node=#{node} mode=#{mode} except=#{except}"
      if reactive_model?(node)
        traverse_model(node, mode, except, pass_model, block)
      elsif reactive_array?(node)
        traverse_array(node, mode, except, pass_model, block)
      elsif reactive_hash?(node)
        traverse_hash(node, mode, except, pass_model, block)
      else
        # go no further
      end
    end

    def traverse_array(array, mode, except, pass_model, block)
      # debug __method__, __LINE__, "array=#{array} mode=#{mode} except=#{except}"
      compute_size(array, mode, except, pass_model, block)
      array.size.times do |i|
        # must access through array[i] to trigger dependency
        compute_value(array, i, ->{ array[i] }, mode, except, pass_model, block)
      end
      unless mode == :shallow 
        array.size.times do |i|
          traverse(array[i], mode, except, pass_model, block)
        end
      end
    end

    def traverse_hash(hash, mode, except, pass_model, block)
      compute_size(hash, mode, except, pass_model, block)
      hash.each_key do |key|
        # must access through hash[key] to trigger dependency
        compute_value(hash, key, ->{ hash[key] }, mode, except, pass_model, block)
      end
      unless mode == :shallow
        hash.each_value do |value|
          traverse(value, mode, except, pass_model, block)
        end
      end
    end

    def traverse_model(model, mode, except, pass_model, block)
      traverse_model_attrs(model, mode, except, pass_model, block)
      traverse_model_fields(model, mode, except, pass_model, block)
    end

    def traverse_model_attrs(model, mode, except, pass_model, block)
      model.attributes.each_key do |attr|
        # must access through get(attr) to trigger dependency
        compute_value(model, attr, ->{ model.get(attr) }, mode, except, pass_model, block)
      end
      unless mode == :shallow
        model.attributes.each_key do |attr|
          traverse(model.get(:"#{attr}"), mode, except, pass_model, block)
        end
      end
    end

    def traverse_model_fields(model, mode, except, pass_model, block)
      fields = model.class.fields_data
      if fields
        fields.each_key do |attr|
          # must access through send(attr) to trigger dependency
          compute_value(model, attr, ->{ model.send(attr) }, mode, except, pass_model, block)
        end
        unless mode == :shallow 
          fields.each_key do |attr|
            traverse(model.send(attr), mode, except, pass_model, block)
          end
        end
      end
    end

    def compute_value(model, locus, value, mode, except, pass_model, block)
      unless except && except.include?(locus)
        compute_term(
          mode,
          pass_model ? ->{ block.call(model, locus, value.call) } : ->{ block.call(locus, value.call) }
        )
      end
    end

    def compute_size(collection, mode, except, pass_model, block)
      unless except && except.include?(:size)
        # debug __method__, __LINE__, "collection=#{collection} mode=#{mode} except=#{except}"
        compute_term(
          mode,
          pass_model ? ->{ block.call(collection, :size, collection.size) } : ->{ block.call(:size, collection.size) }
        )
      end
    end

    def compute_term(mode, proc)
      # :shallow and :node should watch, :root doesn't
      mode == :root ? proc.call : add_watch(proc)
    end

    def add_watch(proc)
      (@watches ||= []) << proc.watch!
    end

    def debug(method, line, msg = nil)
      s = ">>> #{self.class.name}##{method}[#{line}] : #{msg}"
      if RUBY_PLATFORM == 'opal'
        Volt.logger.debug s
      else
        puts s
      end
    end
  end
end
