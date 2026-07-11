class BusinessProfilePolicy < ApplicationPolicy
  def index?; platform_or_superadmin?; end
  def show?; owner_of_record?; end
  def create?; owner_of_record?; end
  def update?; owner_of_record?; end
  def destroy?; platform_or_superadmin?; end
end
