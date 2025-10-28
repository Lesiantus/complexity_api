class CreateComplexityJobs < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto' unless extension_enabled?('pgcrypto')

    create_table :complexity_jobs, id: :uuid do |t|
      t.integer :status, null: false, default: 0
      t.jsonb :input, null: false, default: []
      t.jsonb :result, null: false, default: {}
      t.integer :processed_count, null: false, default: 0
      t.integer :total_count, null: false, default: 0
      t.text :error_message
      t.datetime :completed_at

      t.timestamps
    end

    add_index :complexity_jobs, :status
    add_index :complexity_jobs, :created_at
  end
end
