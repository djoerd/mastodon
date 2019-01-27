# frozen_string_literal: true

class BlacklistedEmailValidator < ActiveModel::Validator
  def validate(user)
    @email = user.email
    user.errors.add(:email, '@utwente.nl or @*.utwente.nl email required') if blocked_email?
  end

  private

  def blocked_email?
    on_blacklist? || not_on_whitelist? || not_utwente_email?
  end

  def on_blacklist?
    return true if EmailDomainBlock.block?(@email)
    return false if Rails.configuration.x.email_domains_blacklist.blank?

    domains = Rails.configuration.x.email_domains_blacklist.gsub('.', '\.')
    regexp  = Regexp.new("@(.+\\.)?(#{domains})", true)

    @email =~ regexp
  end

  def not_on_whitelist?
    return false if Rails.configuration.x.email_domains_whitelist.blank?

    domains = Rails.configuration.x.email_domains_whitelist.gsub('.', '\.')
    regexp  = Regexp.new("@(.+\\.)?(#{domains})$", true)

    @email !~ regexp
  end

  def not_utwente_email?
    regexp = Regexp.new("@(.+\\.)?(utwente.nl)$", true)
    @email !~ regexp
  end
end
