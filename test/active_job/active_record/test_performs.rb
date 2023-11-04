require "test_helper"

module ActiveJob::ActiveRecord; end
class ActiveJob::ActiveRecord::TestPerforms < ActiveSupport::TestCase
  setup do
    Invoice.insert_all [{}, {}, {}, {}, {}]
  end

  test "performs individually" do
    assert_performed_with job: Invoice::DeliverReminderJob, args: [Invoice.first] do
      Invoice.first.deliver_reminder_later!
    end
    perform_enqueued_jobs

    assert Invoice.first.reminded_at
  end

  test "performs bulk" do
    assert_enqueued_jobs 5, only: Invoice::DeliverReminderJob do
      Invoice.all.deliver_reminder_later_bulk!
    end
    perform_enqueued_jobs

    assert_equal 5, Invoice.pluck(:reminded_at).compact.size
  end

  test "performs bulk in_batches" do
    assert_enqueued_jobs 5, only: Invoice::DeliverReminderJob do
      Invoice.in_batches(of: 2).each(&:deliver_reminder_later_bulk!)
    end
    perform_enqueued_jobs

    assert_equal 5, Invoice.pluck(:reminded_at).compact.size
  end

  test "performs bulk on relation" do
    assert_enqueued_jobs 3, only: Invoice::DeliverReminderJob do
      Invoice.where(id: Invoice.first(3)).deliver_reminder_later_bulk!
    end
    perform_enqueued_jobs

    assert_equal 3, Invoice.pluck(:reminded_at).compact.size
  end
end
