# ActiveJob::Performs

`ActiveJob::Performs` adds a `performs` class method to make the model + job loop vastly more conventional. You use it like this:

```ruby
class Post < ApplicationRecord
  performs :publish
  # Or `performs def publish`!

  def publish
    # Some logic to publish a post
  end
end
```

Here's what `performs` generates under the hood:

```ruby
class Post < ApplicationRecord
  class Job < ApplicationJob; end # We build a general Job class to share configuration between method jobs.

  # Individual method jobs inherit from the `Post::Job` defined above.
  class PublishJob < Job
    # We generate the required `perform` method passing in the `post` and calling `publish` on it.
    def perform(post, *, **) = post.publish(*, **)
  end

  # On Rails 7.1+, where `ActiveJob.perform_all_later` exists, we also generate
  # a bulk method to enqueue many jobs at once. So you can do this:
  #
  #   Post.unpublished.in_batches.each(&:publish_later_bulk)
  def self.publish_later_bulk(set = all)
    ActiveJob.perform_all_later set.map { PublishJob.new(_1) }
  end

  # We generate `publish_later` to wrap the job execution forwarding arguments and options.
  def publish_later(*, **) = PublishJob.perform_later(self, *, **)

  def publish
    # Some logic to publish a post.
  end
end
```

## Benefits

1. Conventional Jobs: they'll now mostly call instance methods like `publish_later` -> `publish`.
1. Follows Rails' internal conventions: this borrows from `ActionMailbox::InboundEmail#process_later` calling `process` and `ActionMailer::Base#deliver_later` calling `deliver`.
1. Clarity & less guess work: the `_later` methods standardize how you call jobs throughout your app, so you can instantly tell what's happening.
1. Less tedium: getting an instance method run in the background is just now a `performs` call with some potential configuration.
1. Fewer files to manage: you don't have to dig up something in `app/jobs` just to learn almost nothing from the boilerplate in there.
1. Remaining jobs stand out: `app/jobs` is way lighter, so any jobs in there that don't fit the `performs` pattern now stand out way more.
1. More consolidated logic: sometimes Job classes house model-level logic, but now it's all the way out in `app/jobs` instead of `app/models`, huh?

> [!TIP]
> On that last point, `performs` does put more logic back within your Active Records, so if you need further encapsulation to prevent them growing too large, consider checking out [active_record-associated_object](https://github.com/kaspth/active_record-associated_object).

### Used in production & praise from people

The https://www.rubyevents.org team uses `ActiveJob::Performs` quite a bit:

- [See `performs` calls in RubyEvents](https://github.com/search?q=repo%3Arubyevents%2Frubyevents+performs+language%3ARuby&type=code&l=Ruby)


Here's what [@claudiob](https://github.com/claudiob) had to say after using `ActiveJob::Performs`:

> I’ve been using active_job-performs for the last month and I love it love it love it!!
>
> Your thought process behind it is so thorough. I have a bunch of jobs now attached to models and my app/jobs folder… is empty!!
>
> This saves me a lot of mental hoops, I don’t have to switch between files anymore, everything is self-contained. Thank you!!!

From [@andycroll](https://github.com/andycroll) in a [writeup](https://andycroll.com/ruby/launching-usingrails) about launching [UsingRails](https://usingrails.com):

> I’ve also adopted a couple of gems—with exceptional Rails-level taste and author pedigree—that I hadn’t used in anger before, including `active_job-performs` from Kasper […]. Would recommend both.

And [@nshki](https://github.com/nshki) after trying it:

> Spent some time playing with [@kaspth](https://github.com/kaspth)'s [`ActiveRecord::AssociatedObject`](https://github.com/kaspth/active_record-associated_object) and `ActiveJob::Performs` and wow! The conventions these gems put in place help simplify a codebase drastically. I particularly love `ActiveJob::Performs`—it helped me refactor out all `ApplicationJob` classes I had and keep important context in the right domain model.

## Usage
### with `ActiveRecord::Base` & other `GlobalID::Identification` objects

`ActiveJob::Performs` works with any object that has `include GlobalID::Identification` and responds to that interface.

`ActiveRecord::Base` implements this, so here's how that looks:

```ruby
class Post < ActiveRecord::Base
  extend ActiveJob::Performs # We technically auto-extend ActiveRecord::Base, but other object hierarchies need this.

  # `performs` builds a `Post::PublishJob` and routes configs over to it.
  performs :publish, queue_adapter: :sidekiq, queue_as: :important, discard_on: SomeError do
    retry_on TimeoutError, wait: :polynomially_longer
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
    self.queue_adapter = :sidekiq
    queue_as :important
    discard_on SomeError
    retry_on TimeoutError, wait: :polynomially_longer

    # We generate `perform` passing in the `post` and calling `publish` on it.
    def perform(post, *arguments, **options)
      post.publish(*arguments, **options)
    end
  end

  # On Rails 7.1, where `ActiveJob.perform_all_later` exists, we also generate
  # a bulk method to enqueue many jobs at once. So you can do this:
  #
  #   Post.unpublished.in_batches.each(&:publish_later_bulk)
  #
  # Or pass in a subset of posts as an argument:
  #
  #   Post.publish_later_bulk Post.unpublished
  def self.publish_later_bulk(set = all)
    ActiveJob.perform_all_later set.map { PublishJob.new(_1) }
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

> [!NOTE]
> We prefer & call `{name}=` setter methods, but fall back to getters. That's how we support `self.queue_adapter=`, but also `queue_as` which is not configured via `queue_as=`.

We generate the `Post::Job` class above to share configuration between method level jobs. E.g. if you had a `retract` method that was setup very similar, you could do:

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

#### Establishing patterns across your app

If there's an Active Record method that you'd like any model to be able to run from a background job, you can set them up in your `ApplicationRecord`:

```ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # We're passing specific queues for monitoring, but they're optional.
  performs :update,  queue_as: "active_record.update"
  performs :destroy, queue_as: "active_record.destroy"
end
```

Then a model could now run things like:

```ruby
record.update_later reminded_at: 1.year.ago # Forward along arguments to the eventual `update` call.
record.destroy_later
```

> [!TIP]
> `destroy_later` could be particularly useful on a record with many `dependent: :destroy` associations.
> If anything fails, the transaction will rollback and the job fails, so you can retry it later!

> [!NOTE]
> Maybe you'd rather architect your system such that these methods don't have so many side-effects, but having the option can be handy.

> [!WARNING]
> Don't use this pattern with `touch` because Rails has an internal [touch_later](https://github.com/rails/rails/blob/690ec8898318b8f50714e86676353ebe1551261e/activerecord/lib/active_record/touch_later.rb#L11) private API method used in `belongs_to <some_association>, touch: true` assocations. If your model is one day used in such an assocation and you were using this pattern your app would break.

I haven't tested all the Active Record methods, so please file an issue if you encounter any.

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

Additionally, in case the job is meant to be internal to the object, `performs :some_method` returns `:some_method_later` which you can pass to `private`.

E.g. `private performs :some_method` will generate a private `some_method_later` method.

#### Overriding the generated instance `_later` method

The instance level `_later` methods, like `publish_later` above, are generated into an included module. So in case you have a condition where you'd like to prevent the enqueue, you can override the method and call `super`:

```ruby
class Post < ApplicationRecord
  performs def publish
    # …
  end
  def publish_later = some_condition? && super
end
```

### Usage with `ActiveRecord::AssociatedObject`

The [`ActiveRecord::AssociatedObject`](https://github.com/kaspth/active_record-associated_object) gem also implements `GlobalID::Identification`, so you use `performs` exactly like you would on Active Records:

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

> [!NOTE]
> There's one difference with Active Record: you must pass in a set to `_later_bulk` methods. Like so:
>
> `Post::Publisher.publish_later_bulk Post::Publisher.first(10)`

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
