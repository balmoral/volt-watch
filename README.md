# Volt::Watch

Volt::Watch is a helper mixin to provide simpler syntax and easy management of computation watches in Volt models and controllers.

Watches can can be created for attributes, elements and values of instances of Volt::Model, Volt::ArrayModel, Volt::ReactiveArray and Volt::ReactiveHash.

It further provides for creating watches on the 'internal contents' of any model, array or hash - that is, 
to watch (and react to changes in) any object reachable from a 'root' model, array or hash. 
  
It keeps track of all watches created and provides a method to stop and destroy all watches.
  
## Installation

Add this line to your application's Gemfile:

    gem 'volt-watch'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install volt-watch

## Usage

Include Volt::Watch in your Volt::Model or Volt::Controller.

Then in {action}_ready create the watches.

Examples:
 
1) to watch for a change in a specific attribute of a model,
```
require 'volt-watch'
...
module MyApp
  class MainController < Volt::ModelController
    include Volt::Watch
    ...
    def index_ready
      watch do
        alert "User has changed name to '#{user.name}'}
      end
    end
    ...
  end
end
```

2) to update a view list whenever an item in array of items in store changes:

```
  def index_ready
    on_change_in ->{ store.items } do |index|
      update_list_item(store.items[index], index)
    end
    ...
  end
```

3) to update a chart view component when any attribute in a chart model, or any nested attribute (to any level) changes:

```
  def index_ready
    on_deep_change_in ->{ page._chart } do |locus, value, model|
      # `model` may be page._chart or any of its attributes or their attributes
      # which are models or arrays.
      # `locus` identifies where the change in the model or array has occurred
      # as a symbol (for a model attribute) or integer (for an array element's index).
      # `value` is the new value.
      # If an array has changed size then `model` will be the array, 
      # `locus` will be `:size` and `value` will be the new size.
      update_chart_view(model, locus, value)
    end
    ...
  end
```

**IMPORTANT**

Watches should be terminated when no longer required, such as when the page is left.

To terminate all watches call `stop_watches`. 

For example:

```
def before_index_remove
  stop_watches
end
```

## Contributing

1. Fork it ( http://github.com/[my-github-username]/volt-watch/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
