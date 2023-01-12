## [Unreleased]

- Support method suffixes ! and ?

  You can call `performs :some_method!` and have `some_method_later!` generated. Same for `?`.

- Support `performs` on private methods

  Method jobs will now call methods with `send`, in case you only want to expose the generated later method to the outside world.

  ```ruby
  class Post < ActiveRecord::Base
    performs :something_low_level

    private

    # We don't want other objects to call this, they should always use the generated later method.
    def something_low_level
      # …
    end
  end
  ```

  Here, the generated `Post#something_low_level_later` is public and available but can still call into the immediate version of `something_low_level`.

## [0.1.1] - 2022-09-27

- Fixed: extend ActiveRecord::Base with ActiveJob::Performs as the README says.

## [0.1.0] - 2022-09-27

- Initial release
