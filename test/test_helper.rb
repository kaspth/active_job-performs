# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "active_job"
require "active_job/performs"

require "active_record"
require "debug"
require "minitest/autorun"

class ApplicationJob < ActiveJob::Base; end

GlobalID.app = :performs
GlobalID::Locator.use(:performs) { _1.model_class.find(_1.model_id.to_i) }

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :invoices do |t|
    t.datetime :reminded_at
    t.timestamps
  end
end

class Invoice < ActiveRecord::Base
  include GlobalID::Identification

  performs :deliver_reminder!
  def deliver_reminder!
    touch :reminded_at
  end
end

class Base < Struct.new(:id)
  extend ActiveJob::Performs
  include GlobalID::Identification

  singleton_class.alias_method :find, :new
end

module Post; end
class Post::Publisher < Base
  singleton_class.attr_accessor :performed

  performs queue_as: :not_really_important
  performs :publish, queue_as: :important, discard_on: ActiveJob::DeserializationError do
    retry_on StandardError, wait: :exponentially_longer
  end

  performs :retract, wait: 5.minutes
  performs :social_media_boost!, wait_until: -> publisher { publisher.next_funnel_step_happens_at }

  def next_funnel_step_happens_at
    DateTime.tomorrow.noon
  end

  def publish
    self.class.performed = true
  end

  def retract(reason:)
    puts reason
  end

  def social_media_boost!
    puts "social media soooo boosted"
  end

  private performs def private_method
    puts __method__
  end
end

class ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Override Minitest::Test#run to wrap each test in a transaction.
  def run
    result = nil
    ActiveRecord::Base.transaction(requires_new: true) do
      result = super
      raise ActiveRecord::Rollback
    end
    result
  end
end
