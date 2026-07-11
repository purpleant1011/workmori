puts "invoice count: #{Invoice.count}"
inv = Invoice.first
puts "inv 1: state=#{inv.state} paid_on=#{inv.paid_on}"
puts "payment count: #{Payment.count}"
Payment.all.each do |p|
  puts "  pay id=#{p.id} state=#{p.state} amount=#{p.amount_krw} txn=#{p.provider_txn_id}"
end
puts "audit count: #{AuditEvent.where(action: 'billing.payment.succeeded').count}"
puts "delivery_log billing: #{DeliveryLog.where(kind: 'billing').count}"
puts "subscription count: #{Subscription.count}"
sub = Subscription.first
puts "  sub id=#{sub.id} state=#{sub.state} plan=#{sub.plan.code}"