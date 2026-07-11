class ContentItemPolicy < ApplicationPolicy; def publish?; owner_of_record?; end; end
