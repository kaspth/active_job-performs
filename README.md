# ActiveJob::Performs

`ActiveJob::Performs` is a lightweight DSL for setting up jobs by convention.

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

### Passing waits to `performs`

If there's a job you want to defer a bit, you can have `performs` automatically set it on the job for each invocation:

```ruby
class Post < ActiveRecord::Base
  performs :social_media_boost, wait: 5.minutes # You could fetch it from something like `Rails.application.config_for(:posts).social_media_boost_after` too.
end
```

Now, `social_media_boost_later` can be called from a sequence of steps, but automatically run after the 5 minute grace period.

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
