# All money stored as integer KRW (cents) at the column level. Helpers here keep math
# clean and prevent accidental floats in rate calculations.
module MoneyValueObject
  extend ActiveSupport::Concern

  def as_krw
    read_attribute(:amount_krw) || read_attribute(self.class::MONEY_COLUMN)
  end

  def with_vat(rate = 0.10)
    (as_krw.to_i * (1 + rate)).round
  end
end
