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
      add_watch(target, mode: :basic, action: block)
    end

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

    # Adds a watch for any change to the object returned by
    # 'target' and for any change to any object reachable from
    # the target.
    #
    # The target object may be a Volt::Model, Volt::ArrayModel,
    # Volt::ReactiveArray or Volt::ReactiveHash.
    #
    # 'target' must be a Proc which returns the model, array or hash.
    #
    # If the value of the target object or any reactive object reachable
    # from it changes then the given block will be called with the target
    # object as the argument.
    #
    # Note: use this method when you are watching for changes to the
    # 'contents' of a model/array/hash (and any reachable object) but
    # you DO NOT need to identify what in particular changed.
    def watch_general(target, ignore: nil, &block)
      add_watch(target, mode: :general, ignore: ignore, action: block)
    end

    # Adds a watch for any change to the object returned by
    # 'target' and for any change to any object reachable from
    # the target.
    #
    # The target object may be a Volt::Model, Volt::ArrayModel,
    # Volt::ReactiveArray or Volt::ReactiveHash.
    #
    # 'target' must be a Proc which returns the model, array or hash.
    #
    # If the value of the target object or any reactive object reachable
    # from it changes then the given block will be called with the
    # 'owner' of the changed value as the first argument, the
    # attribute_name/index/key associated with the value as the
    # second argument, and the value itself as the third argument.
    #
    # Note: use this method when you are watching for changes to the
    # 'contents' of a model/array/hash (and any reachable object) and
    # you DO need to identify the particular value that changed.
    def watch_particular(target, ignore: nil, &block)
      add_watch(target, mode: :particular, ignore: ignore, action: block)
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
      raise ArgumentError, 'no block given for watch' unless action
      @watches ||= []
      @watches << case mode
        when :basic
          -> do
            action.call(target.call)
          end
        when :values
          -> do
            compute_values(target) do |key, value|
              action.call(key, value)
            end
          end
        when :general
          -> do
            compute_into(target, false, ignore) do |value|
              action.call(value)
            end
          end
        when :particular
          -> do
            compute_into(target, true, ignore) do |owner, key, value|
              action.call(value, key, owner)
            end
          end
        else
          raise ArgumentError, "unhandled watch mode #{mode.nil? ? 'nil' : mode}"
      end.watch!
    end

    def compute_values(target, &block)
      value = target.call
      if value.is_a?(Volt::Model)
        enumerate_model(value, block)
      elsif value.is_a?(Volt::ReactiveArray)
        enumerate_array(value, block)
      elsif value.is_a?(Volt::ReactiveHash)
        enumerate_hash(value, block)
      end
    end

    def enumerate_array(array, block)
      array.size.times do |i|
        block.call(i, array[i])
      end
    end

    def enumerate_hash(hash, block)
      hash.each_key do |key|
        block.call(key, hash[key])
      end
    end

    def enumerate_model(model, block)
      model.attributes.each_key do |attr|
        _attr = :"_#{attr}"
        block.call(_attr, model.get(_attr))
      end
    end

    def compute_into(target, particular, ignore, &block)
      value = target.call
      yield(value) unless particular # once only here for general
      into_value(nil, nil, value, particular, ignore, block)
    end

    def into_value(owner, key, value, particular, ignore, block)
      yield(owner, key, value) if particular
      if value.is_a?(Volt::Model)
        into_model(value, particular, ignore, block)
      elsif value.is_a?(Volt::ReactiveArray)
        into_array(value, particular, ignore, block)
      elsif value.is_a?(Volt::ReactiveHash)
        into_hash(value, particular, ignore, block)
      end
    end

    def into_array(array, particular, ignore, block)
      # array[i] to trigger dependency
      array.size.times do |i|
        into_value(array, i, array[i], particular, ignore, block)
      end
    end

    def into_hash(hash, particular, ignore, block)
      # hash[key] to trigger dependency
      hash.each_key do |key|
        into_value(hash, key, hash[key], particular, ignore, block)
      end
    end

    def into_model(model, particular, ignore, block)
      # model.send(_attr) to trigger dependency
      model.attributes.each_key do |attr|
        _attr = :"_#{attr}"
        unless ignore && ignore.include?(_attr)
          into_value(model, _attr, model.send(_attr), particular, ignore, block)
        end
      end
    end

  end
end
