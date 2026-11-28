require "rails_helper"

RSpec.describe PageView do
  describe ".visitor_hash" do
    let(:agent) { "Mozilla/5.0 Firefox/140.0" }
    let(:day) { Date.new(2026, 11, 28) }

    it "is stable for the same visitor within a day" do
      expect(described_class.visitor_hash(ip: "203.0.113.7", user_agent: agent, date: day))
        .to eq(described_class.visitor_hash(ip: "203.0.113.7", user_agent: agent, date: day))
    end

    it "changes from one day to the next" do
      expect(described_class.visitor_hash(ip: "203.0.113.7", user_agent: agent, date: day))
        .not_to eq(described_class.visitor_hash(ip: "203.0.113.7", user_agent: agent, date: day + 1))
    end

    it "differs between IP addresses and user agents" do
      hash = described_class.visitor_hash(ip: "203.0.113.7", user_agent: agent, date: day)

      expect(described_class.visitor_hash(ip: "203.0.113.8", user_agent: agent, date: day)).not_to eq(hash)
      expect(described_class.visitor_hash(ip: "203.0.113.7", user_agent: "#{agent} Other", date: day)).not_to eq(hash)
    end

    it "uses the UTC date of the view" do
      request = ActionDispatch::TestRequest.create("REMOTE_ADDR" => "203.0.113.7", "HTTP_USER_AGENT" => agent)
      time = Time.utc(2026, 11, 28, 23, 30)

      attributes = described_class.attributes_for(request, time: time.in_time_zone("Tokyo"))

      expect(attributes[:visitor_hash]).to eq(described_class.visitor_hash(ip: "203.0.113.7", user_agent: agent, date: day))
    end
  end

  describe ".referrer_host" do
    it "keeps only the host of another site" do
      expect(described_class.referrer_host("https://Www.Example.org/some/page?q=1", own_host: "stepsfrom.com")).to eq("www.example.org")
    end

    it "drops this site, with or without www" do
      expect(described_class.referrer_host("https://stepsfrom.com/guides/x", own_host: "stepsfrom.com")).to be_nil
      expect(described_class.referrer_host("https://www.stepsfrom.com/", own_host: "stepsfrom.com")).to be_nil
    end

    it "drops missing and malformed referrers" do
      expect(described_class.referrer_host(nil, own_host: "stepsfrom.com")).to be_nil
      expect(described_class.referrer_host("not a url ^", own_host: "stepsfrom.com")).to be_nil
    end
  end

  describe ".bot?" do
    it "recognises crawlers and tools but not browsers" do
      expect(described_class.bot?("Mozilla/5.0 (compatible; bingbot/2.0)")).to be(true)
      expect(described_class.bot?("Slackbot-LinkExpanding 1.0")).to be(true)
      expect(described_class.bot?(nil)).to be(true)
      expect(described_class.bot?("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15")).to be(false)
    end
  end

  describe ".purge_expired" do
    def view_at(time)
      described_class.create!(occurred_at: time, path: "/", visitor_hash: "abc")
    end

    it "deletes page views older than the retention period" do
      old = view_at(181.days.ago)
      recent = view_at(179.days.ago)

      described_class.purge_expired(batch_size: 1)

      expect(described_class.all).to contain_exactly(recent)
      expect { old.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "takes the retention period from PAGE_VIEW_RETENTION_DAYS" do
      stub_const("ENV", ENV.to_h.merge("PAGE_VIEW_RETENTION_DAYS" => "30"))
      view_at(31.days.ago)
      recent = view_at(29.days.ago)

      described_class.purge_expired

      expect(described_class.all).to contain_exactly(recent)
    end
  end
end
