class CreateKnowledge < ActiveRecord::Migration[8.0]
  def change
    create_table :knowledge_sources do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_employee, foreign_key: true
      t.string  :kind, null: false  # upload | text | url | faq | product
      t.string  :title
      t.text    :url
      t.string  :language, null: false, default: "ko"
      t.text    :tags_json, null: false, default: "[]"
      t.string  :status, null: false, default: "pending" # pending | processing | ready | failed | disabled
      t.text    :error_message
      t.datetime :valid_from
      t.datetime :valid_until
      t.text    :rights_confirmation
      t.boolean :contains_personal_data, null: false, default: false
      t.boolean :ai_training_allowed, null: false, default: false
      t.timestamps
    end

    create_table :knowledge_documents do |t|
      t.references :account, null: false, foreign_key: true
      t.references :knowledge_source, null: false, foreign_key: true
      t.string  :version, null: false, default: "1.0"
      t.text    :raw_text
      t.text    :normalized_text
      t.string  :mime_type
      t.integer :byte_size
      t.string  :checksum_sha256, null: false
      t.text    :extraction_error
      t.integer :pii_warnings_count, null: false, default: 0
      t.string  :status, null: false, default: "pending"  # pending | extracted | indexed | failed
      t.datetime :indexed_at
      t.timestamps
    end

    create_table :document_chunks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :knowledge_document, null: false, foreign_key: true
      t.integer :position, null: false
      t.text    :content, null: false
      t.text    :content_tsvector  # PG tsvector (generated)
      t.string  :content_sha256, null: false
      t.jsonb   :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :document_chunks, :content_sha256

    # 임베딩은 차기 단계. 자리표시자만.
    create_table :embeddings do |t|
      t.references :account, null: false, foreign_key: true
      t.references :document_chunk, null: false, foreign_key: true
      t.string  :provider, null: false
      t.string  :model_code, null: false
      t.integer :dimensions, null: false
      t.text    :vector_data  # 향후 pgvector로 마이그레이션
      t.string  :checksum, null: false
      t.timestamps
    end

    create_table :faqs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_employee, foreign_key: true
      t.string  :question, null: false
      t.text    :answer, null: false
      t.text    :tags_json, null: false, default: "[]"
      t.string  :risk_level, null: false, default: "low"  # low | medium | high
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :products do |t|
      t.references :account, null: false, foreign_key: true
      t.string  :name, null: false
      t.text    :description
      t.integer :base_price_krw
      t.integer :duration_min
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :services do |t|
      t.references :account, null: false, foreign_key: true
      t.string  :name, null: false
      t.text    :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    # 검색 인덱스: PG fulltext
    execute <<~SQL
      CREATE INDEX idx_doc_chunks_tsvector ON document_chunks USING gin (to_tsvector('simple', content));
    SQL
  end
end
