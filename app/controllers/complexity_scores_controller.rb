class ComplexityScoresController < ApplicationController
  before_action :ensure_json_request
  before_action :set_job, only: :show

  # POST /complexity_score
  def create
    words = parse_input
    unless words
      render json: { error: "Request body must be a JSON array of non-empty words" }, status: :bad_request
      return
    end

    job = ComplexityJob.create!(input: words)
    ComplexityScoreWorkerJob.perform_async(job.id)

    render json: { job_id: job.id }, status: :accepted
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  # GET /complexity_score/:id
  def show
    render json: serialize_job(@job)
  end

  private

  def set_job
    @job = ComplexityJob.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Job not found" }, status: :not_found
  end

  # Parse raw JSON body expecting an array of non-empty strings.
  # Returns the array or nil if parsing/validation fails.
  def parse_input
    raw = request.body.read
    data = JSON.parse(raw)
    return nil unless data.is_a?(Array) && data.all? { |w| w.is_a?(String) && w.present? }

    data
  rescue JSON::ParserError
    nil
  end

  # Serialize job for API clients.
  def serialize_job(job)
    case job.status.to_sym
    when :pending, :in_progress
      { status: job.status, processed: job.processed_count, total: job.total_count }
    when :completed
      { status: job.status, result: job.result, completed_at: job.completed_at }
    when :failed
      { status: job.status, error: job.error_message, completed_at: job.completed_at }
    else
      { status: job.status }
    end
  end

  def ensure_json_request
    return if request.format.json?

    render json: { error: "JSON requests only" }, status: :not_acceptable
  end
end
