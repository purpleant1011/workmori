class ConversationParticipant < ApplicationRecord
  include AccountScoped
  belongs_to :account
  belongs_to :conversation
  encrypts :encrypted_contact if respond_to?(:encrypts)
end
