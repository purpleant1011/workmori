module Rag
  # Local stub. Returns up to 3 chunks by token overlap. Real impl hits vector store later.
  class Search
    def self.call(account:, query:, limit: 3)
      query_tokens = query.to_s.downcase.scan(/[가-힣]+|[a-z0-9]+/).uniq
      chunks = DocumentChunk.where(account_id: account.id).includes(knowledge_document: :knowledge_source).to_a
      scored = chunks.map do |c|
        tokens = c.tokens.to_s.downcase
        match_count = query_tokens.count { |t| tokens.include?(t) }
        { chunk: c, score: match_count }
      end.sort_by { |h| -h[:score] }.first(limit)
      scored.select { |h| h[:score] > 0 }.map do |h|
        { document_id: h[:chunk].knowledge_document&.id, snippet: h[:chunk].body_text.to_s[0, 240], score: h[:score], source_title: h[:chunk].knowledge_document&.knowledge_source&.title }
      end
    end
  end

  class Embedding
    # Pseudo-embedding: deterministic integer list of token hashes. Cheap & stable.
    def self.embed(text, dims: 64)
      tokens = text.to_s.downcase.scan(/[가-힣]+|[a-z0-9]+/).uniq
      Array.new(dims) { |i| tokens.map { |t| (t.bytes.sum + i) % 127 }.sum > 0 ? 1 : 0 }
    end
  end
end
