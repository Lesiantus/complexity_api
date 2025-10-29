class ComplexityScoreWorkerJob
  include Sidekiq::Job

  sidekiq_options retry: 3

  BATCH_SIZE = 2
  DEFAULT_RETRY_DELAY = 5
  MAX_FETCH_ATTEMPTS = 3

  def perform(job_id, words = nil, attempts_map = {})
    job = ComplexityJob.find(job_id)
    job.mark_in_progress! if words.nil?

    words ||= job.input
    attempts_map ||= {}

    batch = words.take(BATCH_SIZE)
    remaining = words.drop(BATCH_SIZE)

    rate_limited = false

    batch.each do |word|
      attempts_map[word] ||= 0
      attempts_map[word] += 1

      data = DictionaryClient.fetch_definitions(word)

      if data.is_a?(Hash) && data[:rate_limited]
        delay = data[:retry_after] || DEFAULT_RETRY_DELAY
        to_retry = [word] + remaining
        Rails.logger.info("ComplexityScoreWorker: rate limited, rescheduling #{to_retry.size} word(s) in #{delay}s")
        self.class.perform_in(delay, job_id, to_retry, attempts_map)
        rate_limited = true
        break
      end

      if data.nil? && attempts_map[word] < MAX_FETCH_ATTEMPTS
        Rails.logger.warn("Retry #{attempts_map[word]}/#{MAX_FETCH_ATTEMPTS} for word=#{word}")
        self.class.perform_in(0.5, job_id, [word], attempts_map)
        next
      end

      score = data ? compute_score(data) : nil

      job.with_lock do
        job.result[word] = score
        job.processed_count = job.result.size
        job.save!
      end
    end

    return if rate_limited

    if remaining.any?
      self.class.perform_in(1, job_id, remaining, attempts_map)
    else
      job.mark_completed!(job.result)
    end
  rescue StandardError => e
    job&.mark_failed!(e.message)
    Rails.logger.error("ComplexityScoreWorker failed: #{e.class} - #{e.message}")
  end

  def compute_score(data)
    defs = data[:definitions_count].to_i
    syns = data[:synonyms_count].to_i
    ants = data[:antonyms_count].to_i
    return 0.0 if defs.zero?
    ((syns + ants).to_f / defs).round(2)
  end
end
