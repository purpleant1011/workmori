i = Invoice.find(ARGV[0].to_i)
puts [i.state, i.paid_on, i.payments.last&.provider_txn_id, i.payments.last&.state].join("|")