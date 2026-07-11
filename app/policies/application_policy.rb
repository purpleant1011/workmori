# frozen_string_literal: true
class ApplicationPolicy
  class Forbidden < StandardError; end

  attr_reader :user, :platform_staff, :record

  def initialize(user_or_context, record = nil)
    @user = user_or_context.is_a?(User) ? user_or_context : nil
    @platform_staff = user_or_context.is_a?(PlatformStaff) ? user_or_context : nil
    @record = record
  end

  def index?; platform_or_superadmin?; end
  def show?; platform_or_superadmin? || owner_of_record?; end
  def create?; platform_or_superadmin? || owner_of_record?; end
  def update?; platform_or_superadmin? || owner_of_record?; end
  def destroy?; platform_or_superadmin? || owner_of_record?; end

  def platform_or_superadmin?
    return true if platform_staff&.super_admin?
    return true if platform_staff&.role == "ops"
    false
  end

  def owner_of_record?
    return false unless user
    return false unless record
    user.account_id == record.account_id
  end

  class Scope
    def initialize(user_or_context, scope)
      @user = user_or_context.is_a?(User) ? user_or_context : nil
      @platform_staff = user_or_context.is_a?(PlatformStaff) ? user_or_context : nil
      @scope = scope
    end

    def resolve
      return @scope if @platform_staff && %w[super_admin ops].include?(@platform_staff.role)
      return @scope.none unless @user
      @scope.where(account_id: @user.account_id)
    end
  end
end
