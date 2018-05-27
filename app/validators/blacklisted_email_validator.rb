# frozen_string_literal: true

class BlacklistedEmailValidator < ActiveModel::Validator
  def validate(user)
    user.errors.add(:email, '@utwente.nl or @*.utwente.nl email required') if blocked_email?(user.email)
  end

  private

  def blocked_email?(value)
    on_blacklist?(value) || not_on_whitelist?(value) || not_utwente_email?(value)
  end

  def on_blacklist?(value)
    return true if EmailDomainBlock.block?(value)
    return false if Rails.configuration.x.email_domains_blacklist.blank?

    domains = Rails.configuration.x.email_domains_blacklist.gsub('.', '\.')
    regexp  = Regexp.new("@(.+\\.)?(#{domains})", true)

    value =~ regexp
  end

  def not_on_whitelist?(value)
    return false if Rails.configuration.x.email_domains_whitelist.blank?

    domains = Rails.configuration.x.email_domains_whitelist.gsub('.', '\.')
    regexp  = Regexp.new("@(.+\\.)?(#{domains})$", true)

    value !~ regexp
  end

  def not_utwente_email?(value)
    regexp = Regexp.new("@(.+\\.)?(utwente.nl)$", true)
    value !~ regexp
  end
end
