# ActiveJob::Performs

`ActiveJob::Performs` adds the `performs` macro to set up jobs by convention.

## Usage with `include GlobalID::Identification` objects

`ActiveJob::Performs` works with any object that has `include GlobalID::Identification` and responds to that interface.

`ActiveRecord::Base` implements this, so here's how that looks:

```ruby
class Post < ActiveRecord::Base
  extend ActiveJob::Performs # We technically auto-extend ActiveRecord::Base, but other object hierarchies need this.

  # `performs` builds a `Post::PublishJob` and routes configs over to it.
  performs :publish, queue_as: :important, discard_on: SomeError do
    retry_on TimeoutError, wait: :exponentially_longer
  end

  def publish
    …
  end
end
```

Here's what `performs` generates under the hood:

```ruby
class Post < ActiveRecord::Base
  # We setup a general Job class that's shared between method jobs.
  class Job < ApplicationJob; end

  # Individual method jobs inherit from the `Post::Job` defined above.
  class PublishJob < Job
    queue_as :important
    discard_on SomeError
    retry_on TimeoutError, wait: :exponentially_longer

    # We generate `perform` passing in the `post` and calling `publish` on it.
    def perform(post, *arguments, **options)
      post.publish(*arguments, **options)
    end
  end

  # We generate `publish_later` to wrap the job execution.
  def publish_later(*arguments, **options)
    PublishJob.perform_later(self, *arguments, **options)
  end

  def publish
    …
  end
end
```

We generate the `Post::Job` class above to share configuration between method level jobs. E.g. if you had a retract method that was setup very similar, you could do:

```ruby
class Post < ActiveRecord::Base
  performs queue_as: :important
  performs :publish
  performs :retract

  def publish
    …
  end

  def retract(reason:)
    …
  end
end
```

Which would then become:

```ruby
class Post < ActiveRecord::Base
  class Job < ApplicationJob
    queue_as :important
  end

  class PublishJob < Job
    …
  end

  class RetractJob < Job
    …
  end

  …
end
```

#### Method suffixes

`ActiveJob::Performs` supports Ruby's stylistic method suffixes, i.e. ? and ! respectively.

```ruby
class Post < ActiveRecord::Base
  performs :publish! # Generates `publish_later!` which calls `publish!`.
  performs :retract? # Generates `retract_later?` which calls `retract?`.

  def publish!
    …
  end

  def retract?
    …
  end
end
```

#### Private methods

`ActiveJob::Performs` also works with private methods in case you only want to expose the generated `_later` method.

```ruby
class Post < ActiveRecord::Base
  performs :publish # Generates the public `publish_later` instance method.

  # Private implementation, only call `publish_later` please!
  private def publish
    …
  end
end
```

Additionally, in case the job is just meant to be internal to the object, `performs :some_method` returns `:some_method_later` which you can pass to `private`.

E.g. `private performs :some_method` will generate a private `some_method_later` method.

### Usage with ActiveRecord::AssociatedObject

The [`ActiveRecord::AssociatedObject`](https://github.com/kaspth/active_record-associated_object) gem also implements `GlobalID::Identification`, so you can do this too:

```ruby
class Post::Publisher < ActiveRecord::AssociatedObject
  extend ActiveJob::Performs # We technically auto-extend ActiveRecord::AssociatedObject, but other object hierarchies need this.

  performs queue_as: :important
  performs :publish
  performs :retract

  def publish
    …
  end

  def retract(reason:)
    …
  end
end
```

### Passing `wait` to `performs`

If there's a job you want to defer, `performs` can set it for each invocation:

```ruby
class Post < ActiveRecord::Base
  mattr_reader :config, default: Rails.application.config_for(:posts)

  performs :social_media_boost, wait: config.social_media_boost_after
  performs :social_media_boost, wait: 5.minutes # Alternatively, this works too.

  # Additionally, a block can be passed to have access to the `post`:
  performs :social_media_boost, wait: -> post { post.social_media_boost_grace_period }
end
```

Now, `social_media_boost_later` can be called immediately, but automatically run after the grace period.

`wait_until` is also supported:

```ruby
class Post < ActiveRecord::Base
  performs :publish, wait_until: -> post { Date.tomorrow.noon if post.graceful? }
end
```

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add active_job-performs

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install active_job-performs

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kaspth/active_job-performs.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
