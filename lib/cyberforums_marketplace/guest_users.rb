# frozen_string_literal: true

module ::CyberforumsMarketplace
  # Replaces product-comments' ensure-guest.rb (rails runner via docker exec).
  # Difference on purpose: an existing *real* (non-staged) account is never
  # renamed or edited from a public comment form.
  module GuestUsers
    class Error < StandardError
    end

    def self.ensure!(email:, name:, preferred_username:, website: nil, avatar_url: nil)
      email = email.to_s.strip.downcase
      name = name.to_s.strip.presence || "访客"
      preferred = preferred_username.to_s.strip
      raise Error, "email_required" if email.empty? || !EmailAddressValidator.valid_value?(email)
      raise Error, "username_required" if preferred.empty?

      user = UserEmail.find_by(email: email)&.user
      if user.nil?
        user =
          User.new(
            email: email,
            username: UserNameSuggester.suggest(preferred),
            name: name,
            staged: true,
            active: true,
            approved: true,
            trust_level: TrustLevel[0],
            password: SecureRandom.hex(24),
          )
        user.skip_email_validation = true if user.respond_to?(:skip_email_validation=)
        user.save!
      elsif user.staged
        user.update!(name: name) if user.name != name
      end

      if user.staged
        profile = user.user_profile || user.create_user_profile!
        profile.update!(website: website) if website.present?
        begin
          user.create_user_avatar! if user.user_avatar.nil?
          UserAvatar.import_url_for_user(avatar_url, user) if avatar_url.present?
        rescue StandardError => e
          Rails.logger.warn("[cyberforums-marketplace] guest avatar #{e.class}")
        end
      end

      {
        id: user.id,
        username: user.username,
        name: user.name,
        website: user.user_profile&.website,
        avatar_template: user.avatar_template,
        staged: user.staged,
      }
    end
  end
end
