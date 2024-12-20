# frozen_string_literal: true

require_relative "performs/version"

module ActiveJob; end
module ActiveJob::Performs
  module Waiting
    def Proc(value)
      value.respond_to?(:call) ? value : proc { value }
    end unless Kernel.respond_to?(:Proc) # Optimistically assume Ruby gets this and it'll work fine.

    def wait(value = nil)
      @wait = Proc(value) if value
      @wait
    end

    def wait_until(value = nil)
      @wait_until = Proc(value) if value
      @wait_until
    end

    def scoped_by_wait(record)
      if waits = { wait: wait&.call(record), wait_until: wait_until&.call(record) }.compact and waits.any?
        set(waits)
      else
        self
      end
    end
  end

  def performs(method = nil, **configs, &block)
    @job ||= safe_define("Job") { ApplicationJob }.tap { _1.extend Waiting }

    if method.nil?
      apply_performs_to(@job, **configs, &block)
    else
      method = method.to_s.dup
      suffix = $1 if method.gsub!(/([!?])$/, "")

      job = safe_define("#{method}_job".classify) { @job }
      apply_performs_to(job, **configs, &block)

      job.class_eval <<~RUBY, __FILE__, __LINE__ + 1 unless job.instance_method(:perform).owner == job
        def perform(object, *arguments, **options)
          object.send(:#{method}#{suffix}, *arguments, **options)
        end
      RUBY

      if ActiveJob.respond_to?(:perform_all_later)
        class_eval <<~RUBY, __FILE__, __LINE__ + 1
          def self.#{method}_later_bulk#{suffix}(set#{" = all" if respond_to?(:all)})
            ActiveJob.perform_all_later set.map { #{job}.scoped_by_wait(_1).new(_1) }
          end
        RUBY
      end

      performs_later_methods.class_eval <<~RUBY, __FILE__, __LINE__ + 1
        def #{method}_later#{suffix}(*arguments, **options)
          #{job}.scoped_by_wait(self).perform_later(self, *arguments, **options)
        end
      RUBY

      [method, :"#{method}_later#{suffix}"] # Ensure `private performs :some_method` privates both names.
    end
  end

  private
    def safe_define(name)
      name.safe_constantize || const_set(name, Class.new(yield))
    end

    def apply_performs_to(job_class, **configs, &block)
      configs.each { job_class.public_send(_1, _2) }
      job_class.class_exec(&block) if block_given?
    end

    def performs_later_methods
      @performs_later_methods ||= Module.new.tap { include _1 }
    end
end

ActiveSupport.on_load(:active_record) { extend ActiveJob::Performs }
