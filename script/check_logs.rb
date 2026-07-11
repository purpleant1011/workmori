puts DeliveryLog.where(kind: "billing").count
puts AuditEvent.where(action: "billing.payment.succeeded").count