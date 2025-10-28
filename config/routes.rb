require "sidekiq/web"
Rails.application.routes.draw do
  mount Sidekiq::Web => "/sidekiq"

  scope :complexity_score do
    post "/", to: "complexity_scores#create"
    get "/:id", to: "complexity_scores#show"
  end
end
