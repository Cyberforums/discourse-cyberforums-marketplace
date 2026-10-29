# frozen_string_literal: true

RSpec.describe CyberforumsMarketplace::WooSync do
  fab!(:merchant) { Fabricate(:user, email: "boss@example.com") }
  fab!(:helper_user, :user)

  let(:t0) { Time.utc(2026, 10, 29, 0, 0, 0) }

  def payload(overrides = {}, vendor = {})
    {
      "schema" => described_class::SCHEMA,
      "event" => "vendor.updated",
      "reason" => "meta_changed",
      "generated_at" => (overrides.delete(:at) || t0).iso8601,
      "site_url" => "https://market.test/",
      "vendor" => {
        "wp_user_id" => 42,
        "email" => "Boss@Example.com",
        "approved" => true,
        "is_vendor" => true,
        "store_name" => "Acme 小店",
        "store_slug" => "acme",
      }.merge(vendor),
    }.merge(overrides.transform_keys(&:to_s))
  end

  before { SiteSetting.cyberforums_marketplace_enabled = true }

  describe "signature" do
    it "accepts the WooCommerce HMAC-SHA256 base64 signature and rejects others" do
      body = '{"a":1}'
      sig = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", "s3cret", body))
      expect(described_class.valid_signature?(body, sig, "s3cret")).to eq(true)
      expect(described_class.valid_signature?(body, sig, "other")).to eq(false)
      expect(described_class.valid_signature?(body + " ", sig, "s3cret")).to eq(false)
      expect(described_class.valid_signature?(body, "", "s3cret")).to eq(false)
      expect(described_class.valid_signature?(body, sig, "")).to eq(false)
    end
  end

  describe "approved merchant" do
    it "creates shop-<slug> with the shop preset, fields and the owner matched by email" do
      result = described_class.apply!(payload)
      expect(result).to include(
        result: "applied",
        action: "created",
        group: "shop-acme",
        owner: "added",
      )

      group = Group.find_by(name: "shop-acme")
      expect(group.full_name).to eq("Acme 小店")
      expect(group.visibility_level).to eq(Group.visibility_levels[:members])
      expect(group.group_users.find_by(user_id: merchant.id).owner).to eq(true)
      expect(group.custom_fields["mc_source"]).to eq("woocommerce")
      expect(group.custom_fields["mc_status"]).to eq("active")
      expect(group.custom_fields["mc_wp_store_id"]).to eq("42")
      expect(group.custom_fields["mc_display_name"]).to eq("Acme 小店")
      expect(SiteSetting.pm_tags_allowed_for_groups.split("|")).to include(group.id.to_s)
      expect(UserHistory.where(custom_type: described_class::LOG_TYPE).count).to eq(1)
      # chat entry stays off until an admin enables it
      expect(CyberforumsMarketplace::VendorFields.for_group(group)[:enabled]).to eq(false)
    end

    it "is idempotent" do
      described_class.apply!(payload)
      result = described_class.apply!(payload(at: t0 + 1))
      expect(result).to include(action: "updated", owner: "already_owner")
      expect(Group.where("name LIKE 'shop-%'").count).to eq(1)
      expect(Group.find_by(name: "shop-acme").group_users.count).to eq(1)
    end

    it "marks the owner pending without creating an account when no forum user matches" do
      expect {
        described_class.apply!(payload({}, "email" => "nobody@example.com"))
      }.not_to change { User.count }
      group = Group.find_by(name: "shop-acme")
      expect(group.users).to be_empty
      expect(group.custom_fields["mc_owner_pending"]).to eq(true)
      expect(group.custom_fields["mc_owner_email_masked"]).to eq("n***@e***.com")
      expect(group.custom_fields.values.join(" ")).not_to include("nobody@example.com")
    end

    it "does not match staged, inactive or suspended accounts" do
      Fabricate(:user, email: "staged@example.com", staged: true)
      Fabricate(:user, email: "inactive@example.com", active: false)
      Fabricate(
        :user,
        email: "susp@example.com",
        suspended_till: 1.year.from_now,
        suspended_at: Time.zone.now,
      )
      %w[staged inactive susp].each_with_index do |who, i|
        r =
          described_class.apply!(
            payload(
              {},
              "wp_user_id" => 100 + i,
              "email" => "#{who}@example.com",
              "store_slug" => "s#{i}",
            ),
          )
        expect(r[:owner]).to eq("pending")
      end
    end

    it "completes a pending owner on a later sync once the account exists" do
      described_class.apply!(payload({}, "email" => "later@example.com"))
      late = Fabricate(:user, email: "later@example.com")
      result = described_class.apply!(payload({ at: t0 + 60 }, "email" => "later@example.com"))
      expect(result[:owner]).to eq("added")
      group = Group.find_by(name: "shop-acme")
      expect(group.group_users.find_by(user_id: late.id).owner).to eq(true)
      expect(group.custom_fields["mc_owner_pending"]).to eq(false)
    end

    it "keeps the previous owner and flags the shop for manual review when the owner changes" do
      described_class.apply!(payload)
      newcomer = Fabricate(:user, email: "next@example.com")
      result = described_class.apply!(payload({ at: t0 + 60 }, "email" => "next@example.com"))
      expect(result[:owner]).to eq("added_previous_kept")
      group = Group.find_by(name: "shop-acme")
      expect(group.group_users.find_by(user_id: merchant.id).owner).to eq(true)
      expect(group.group_users.find_by(user_id: newcomer.id).owner).to eq(true)
      expect(group.custom_fields["mc_owner_review"]).to eq(true)
      expect(group.custom_fields["mc_owner_review_previous"]).to eq(merchant.username)
      expect(CyberforumsMarketplace::VendorFields.notices_for(group)).to include(
        "owner_changed_review",
      )
      log = UserHistory.where(custom_type: CyberforumsMarketplace::WooSync::LOG_TYPE).last
      expect(log.details).to include("added_previous_kept")
    end

    it "does not flag a review when the first owner is added to an adopted group" do
      pilot = Fabricate(:group, name: "shop-demo-wenpai")
      pilot.add(helper_user)
      described_class.apply!(payload({}, "store_slug" => "demo-wenpai"))
      expect(pilot.reload.custom_fields["mc_owner_review"]).to be_blank
    end

    it "adopts an existing unsynced shop group (pilot shop) without touching its settings or members" do
      pilot = Fabricate(:group, name: "shop-demo-wenpai", messageable_level: 99)
      pilot.add(helper_user)
      result = described_class.apply!(payload({}, "store_slug" => "demo-wenpai"))
      expect(result).to include(action: "updated", group: "shop-demo-wenpai")
      pilot.reload
      expect(pilot.messageable_level).to eq(99)
      expect(pilot.users).to include(helper_user, merchant)
      expect(pilot.custom_fields["mc_wp_store_id"]).to eq("42")
    end

    it "refuses a slug already mirrored for another merchant" do
      described_class.apply!(payload)
      r = described_class.apply!(payload({}, "wp_user_id" => 43, "email" => "x@example.com"))
      expect(r).to include(result: "rejected", reason: "store_slug_taken")
    end

    it "refuses missing, invalid or too long slugs and never creates the group" do
      expect(described_class.apply!(payload({}, "store_slug" => ""))[:reason]).to eq(
        "store_slug_missing",
      )
      expect(described_class.apply!(payload({}, "store_slug" => "店铺"))[:reason]).to eq(
        "store_slug_missing",
      )
      expect(described_class.apply!(payload({}, "store_slug" => "a" * 16))[:reason]).to eq(
        "store_slug_too_long",
      )
      expect(Group.where("name LIKE 'shop-%'").count).to eq(0)
    end

    it "normalises the store slug" do
      described_class.apply!(payload({}, "store_slug" => "  Acme Shop!! "))
      expect(Group.find_by(name: "shop-acme-shop")).to be_present
    end

    it "keeps the group name when the store slug changes later and reports a notice" do
      described_class.apply!(payload)
      described_class.apply!(payload({ at: t0 + 1 }, "store_slug" => "acme-two"))
      group = Group.find_by(name: "shop-acme")
      expect(group).to be_present
      expect(Group.find_by(name: "shop-acme-two")).to be_nil
      expect(CyberforumsMarketplace::VendorFields.notices_for(group)).to include(
        "store_slug_changed",
      )
    end

    it "ignores out-of-order (older) snapshots" do
      described_class.apply!(payload(at: t0 + 100))
      r = described_class.apply!(payload({ at: t0 }, "approved" => false))
      expect(r[:result]).to eq("stale_ignored")
      expect(Group.find_by(name: "shop-acme").custom_fields["mc_status"]).to eq("active")
    end
  end

  describe "disabled or deleted merchant" do
    before do
      described_class.apply!(payload)
      Group.find_by(name: "shop-acme").add(helper_user)
    end

    it "only marks the shop disabled; members stay and the group is kept" do
      r = described_class.apply!(payload({ at: t0 + 10 }, "approved" => false))
      expect(r).to include(action: "disabled", status: "disabled")
      group = Group.find_by(name: "shop-acme")
      expect(group.users).to include(merchant, helper_user)
      expect(group.custom_fields["mc_status"]).to eq("disabled")
    end

    it "treats a deleted WordPress user or a user leaving the vendor group the same way" do
      described_class.apply!(payload({ at: t0 + 10, event: "vendor.deleted" }))
      expect(Group.find_by(name: "shop-acme").custom_fields["mc_status"]).to eq("disabled")
      described_class.apply!(payload({ at: t0 + 20 }, "is_vendor" => true))
      expect(Group.find_by(name: "shop-acme").custom_fields["mc_status"]).to eq("active")
      described_class.apply!(payload({ at: t0 + 30 }, "is_vendor" => false))
      group = Group.find_by(name: "shop-acme")
      expect(group.custom_fields["mc_status"]).to eq("disabled")
      expect(group.users.count).to eq(2)
    end
  end

  it "ignores merchants that are not approved and have no shop yet" do
    r = described_class.apply!(payload({}, "approved" => false))
    expect(r).to include(result: "ignored", reason: "not_approved")
    expect(Group.where("name LIKE 'shop-%'").count).to eq(0)
  end

  it "rejects malformed payloads" do
    expect { described_class.apply!(payload("schema" => "x")) }.to raise_error(
      described_class::Invalid,
    )
    expect { described_class.apply!(payload({}, "wp_user_id" => "abc")) }.to raise_error(
      described_class::Invalid,
    )
    expect { described_class.apply!(payload("generated_at" => "nope")) }.to raise_error(
      described_class::Invalid,
    )
    expect { described_class.apply!(payload(event: "vendor.exploded")) }.to raise_error(
      described_class::Invalid,
    )
  end

  it "records the last receive and reconcile times" do
    described_class.apply!(payload("reason" => "reconcile"))
    s = described_class.status
    expect(s[:last_received_at]).to be_present
    expect(s[:last_reconcile_at]).to be_present
    expect(s[:reconcile_stale]).to eq(false)
  end
end
