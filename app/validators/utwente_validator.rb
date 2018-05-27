# frozen_string_literal: true

class UtwenteValidator < ActiveModel::Validator
  def validate(account)
    return if !account.local? || account.user.confirmed?
    account.errors.add(:username, 'Because this username has 8 characters or fewer, it can only be registered with the email address %s@utwente.nl.' % account.username) if account.username.length <= 8 && !account.user.email.eql?([account.username, '@utwente.nl'].join)
  end
end
