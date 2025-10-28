class ComplexityScoreWorkerJob
  include Sidekiq::Job

  sidekiq_options retry: 3

  BATCH_SIZE = 2
  DEFAULT_RETRY_DELAY = 5

  # Process job input in small batches and reschedule to enforce rate-limiting.
  def perform(job_id, words = nil, accumulated = {})
    job = ComplexityJob.find(job_id)
    job.mark_in_progress! if words.nil?

    words ||= job.input
    accumulated ||= {}

    batch = words.take(BATCH_SIZE)
    remaining = words.drop(BATCH_SIZE)

    rate_limited = false

    batch.each do |word|
      data = DictionaryClient.fetch_definitions(word)

      if data.is_a?(Hash) && data[:rate_limited]
        delay = data[:retry_after] || DEFAULT_RETRY_DELAY
        to_retry = [word] + remaining
        Rails.logger.info("ComplexityScoreWorker: rate limited, rescheduling #{to_retry.size} word(s) in #{delay}s")
        self.class.perform_in(delay, job_id, to_retry, accumulated)
        rate_limited = true
        break
      end

      accumulated[word] = data ? compute_score(data) : nil
    end

    return if rate_limited

    if remaining.any?
      self.class.perform_in(1, job_id, remaining, accumulated)
    else
      job.mark_completed!(accumulated)
    end
  rescue StandardError => e
    job&.mark_failed!(e.message)
    Rails.logger.error("ComplexityScoreWorker failed: #{e.class} - #{e.message}")
  end

  # Compute complexity score from parsed dictionary data.
  def compute_score(data)
    defs = data[:definitions_count].to_i
    syns = data[:synonyms_count].to_i
    ants = data[:antonyms_count].to_i

    return 0.0 if defs.zero?

    ((syns + ants).to_f / defs).round(2)
  end
end
