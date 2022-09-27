# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "active_job"
require "active_job/performs"

require "minitest/autorun"

class ApplicationJob < ActiveJob::Base; end

GlobalID.app = :performs
GlobalID::Locator.use(:performs) { Post::Publisher.new(_1.model_id.to_i) }

module Post; end

class Base < Struct.new(:id)
  include GlobalID::Identification
  singleton_class.alias_method :find, :new
end

class Post::Publisher < Base
  extend ActiveJob::Performs

  singleton_class.attr_accessor :performed

  performs queue_as: :not_really_important
  performs :publish, queue_as: :important, discard_on: ActiveJob::DeserializationError

  performs :retract, wait: 5.minutes

  def publish
    self.class.performed = true
  end

  def retract(reason:)
    puts reason
  end
end
