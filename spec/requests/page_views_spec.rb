require "rails_helper"

RSpec.describe "Page view counting" do
  let(:browser) { "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0" }
  let(:phone) { "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1" }

  def visit_page(path = privacy_path, headers: {}, **options)
    get path, headers: { "User-Agent" => browser }.merge(headers), **options
  end

  it "records a page view of a normal page without the IP address or user agent" do
    freeze_time do
      expect {
        visit_page privacy_path(utm_source: "newsletter", q: "x"),
                   headers: { "Referer" => "https://www.google.com/search?q=beachfront", "REMOTE_ADDR" => "203.0.113.7" }
      }.to change(PageView, :count).by(1)

      expect(response).to have_http_status(:ok)
      view = PageView.last
      expect(view).to have_attributes(path: "/privacy", referrer_host: "www.google.com", utm_source: "newsletter",
                                      utm_medium: nil, country: nil, device: "desktop", occurred_at: Time.current)
      expect(view.visitor_hash).to eq(PageView.visitor_hash(ip: "203.0.113.7", user_agent: browser, date: Date.current))
      expect(view.visitor_hash).to match(/\A\h{16}\z/)
      stored = view.attributes.values.map(&:to_s).join(" ")
      expect(stored).not_to include("203.0.113.7", "Firefox", "Mozilla")
    end
  end

  it "records the device class and a country from CF-IPCountry" do
    visit_page headers: { "User-Agent" => phone, "CF-IPCountry" => "de" }

    expect(PageView.last).to have_attributes(device: "mobile", country: "DE")
  end

  it "ignores an unknown CF-IPCountry code" do
    visit_page headers: { "CF-IPCountry" => "XX" }

    expect(PageView.last.country).to be_nil
  end

  it "drops a referrer from this site" do
    visit_page headers: { "Referer" => "http://www.example.com/destinations/makarska" }

    expect(PageView.last.referrer_host).to be_nil
  end

  it "truncates long UTM values" do
    visit_page privacy_path(utm_campaign: "a" * 300, utm_medium: [ "x" ])

    expect(PageView.last.utm_campaign).to eq("a" * 100)
    expect(PageView.last.utm_medium).to be_nil
  end

  it "counts the home page" do
    expect { visit_page root_path }.to change(PageView, :count).by(1)
    expect(PageView.last.path).to eq("/")
  end

  describe "requests that are not counted" do
    it "skips bots, link previews, HTTP libraries and requests without a user agent" do
      [
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
        "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
        "Mozilla/5.0 (compatible; AhrefsBot/7.0; +http://ahrefs.com/robot/)",
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/130.0 Safari/537.36",
        "curl/8.5.0", "Wget/1.21", "python-requests/2.32.3", "WhatsApp/2.23", ""
      ].each { |agent| visit_page headers: { "User-Agent" => agent } }

      expect(response).to have_http_status(:ok)
      expect(PageView.count).to eq(0)
    end

    it "skips Do Not Track and Global Privacy Control requests" do
      visit_page headers: { "DNT" => "1" }
      visit_page headers: { "Sec-GPC" => "1" }

      expect(PageView.count).to eq(0)
    end

    it "skips prefetches and the automatic reload with fresh prices" do
      visit_page headers: { "Sec-Purpose" => "prefetch" }
      visit_page privacy_path(priced: 1)

      expect(PageView.count).to eq(0)
    end

    it "skips the admin" do
      sign_in_admin
      visit_page admin_properties_path

      expect(response).to have_http_status(:ok)
      expect(PageView.count).to eq(0)
    end

    it "skips outbound redirects" do
      visit_page outbound_path(create(:listing))

      expect(response).to have_http_status(:found)
      expect(PageView.count).to eq(0)
    end

    it "skips non-HTML, not-found and HEAD requests" do
      visit_page sitemap_path
      visit_page robots_path
      visit_page rails_health_check_path
      visit_page destination_path("nowhere")
      expect(response).to have_http_status(:not_found)
      head privacy_path, headers: { "User-Agent" => browser }

      expect(PageView.count).to eq(0)
    end
  end

  it "never breaks the page when recording fails" do
    allow(PageView).to receive(:insert).and_raise(ActiveRecord::StatementInvalid, "database unavailable")
    allow(Rails.logger).to receive(:warn)

    visit_page

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Privacy")
    expect(Rails.logger).to have_received(:warn).with(/Page view not recorded/)
  end
end
