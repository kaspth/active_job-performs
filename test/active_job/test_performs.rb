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

  test "a general job class is defined with queue_as set" do
    assert defined?(Post::Publisher::Job)
    assert_equal "not_really_important", Post::Publisher::Job.queue_name
  end

  test "active job integration" do
    assert_performed_with job: Post::Publisher::PublishJob, args: [ @publisher ], queue: "important" do
      @publisher.publish_later
    end

    assert Post::Publisher.performed
  end

  test "supports private methods" do
    assert_includes Post::Publisher.private_instance_methods, :private_method_later

    assert_output "private_method\n" do
      assert_performed_with job: Post::Publisher::PrivateMethodJob, args: [ @publisher ] do
        @publisher.send(:private_method_later)
      end
    end
  end

  test "wait is forwarded" do
    assert_enqueued_with job: Post::Publisher::RetractJob, args: [ @publisher, reason: "Some reason" ], at: 5.minutes.from_now do
      @publisher.retract_later reason: "Some reason"
    end

    assert_output "Some reason\n" do
      perform_enqueued_jobs
    end
  end

  test "wait_until with instance context" do
    assert_enqueued_with job: Post::Publisher::SocialMediaBoostJob, args: [ @publisher ], at: Date.tomorrow.noon do
      @publisher.social_media_boost_later!
    end

    assert_output "social media soooo boosted\n" do
      perform_enqueued_jobs
    end
  end
end
