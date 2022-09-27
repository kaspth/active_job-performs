# frozen_string_literal: true

require "test_helper"

class ActiveJob::TestPerforms < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    Post::Publisher.performed = false
    @publisher = Post::Publisher.new(1)
  end

  test "version number" do
    refute_nil ::ActiveJob::Performs::VERSION
  end

  test "a general job class is defined" do
    assert defined?(Post::Publisher::Job)
  end

  test "active job integration" do
    assert_performed_with job: Post::Publisher::PublishJob, args: [ @publisher ], queue: "important" do
      @publisher.publish_later
    end

    assert Post::Publisher.performed
  end
end
