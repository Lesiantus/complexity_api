class ComplexityJob < ApplicationRecord
  enum :status, %i[pending in_progress completed failed]

  validates :input, presence: true
  validate :input_is_array_of_strings

  before_validation :set_total_count, on: :create

  def mark_in_progress!
    update!(status: :in_progress)
  end

  def mark_completed!(result_hash)
    update!(status: :completed, result: result_hash, processed_count: result_hash.size, completed_at: Time.current)
  end

  def mark_failed!(error_message)
    update!(status: :failed, error_message: error_message, completed_at: Time.current)
  end

  private

  def set_total_count
    self.total_count = input.is_a?(Array) ? input.size : 0
  end

  def input_is_array_of_strings
    unless input.is_a?(Array) && input.all? { |w| w.is_a?(String) && w.present? }
      errors.add(:input, "must be an array of non-empty strings")
    end
  end
end
