i = Invoice.first
puts "before: inv.state=#{i.state}"
res = Billing::PaymentCollector.call(invoice: i)
puts "ok=#{res.ok} error=#{res.error.inspect}"
puts "payment=#{res.payment.inspect}" if res.payment
puts "invoice reload: state=#{i.reload.state} paid_on=#{i.paid_on}"
puts "Payment.count: #{Payment.count}"
Payment.all.each { |p| puts "  pay id=#{p.id} state=#{p.state}" }