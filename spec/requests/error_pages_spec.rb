require "rails_helper"

RSpec.describe "Error pages" do
  describe "unknown path (catch-all route)" do
    before { sign_in(create(:user)) }

    it "renders a 404 page that links back to the start page" do
      get "/no/such/page"

      page = Nokogiri::HTML(response.body)

      expect(response).to have_http_status(:not_found)
      expect(page.at_css("main h1").text).to include("Page not found")
      expect(page.at_css("main a[href='/']")).to be_present
    end
  end

  describe "static pages in public/" do
    %w[400 404 406-unsupported-browser 422 500 503].each do |name|
      describe "public/#{name}.html" do
        let(:page) { Nokogiri::HTML(Rails.public_path.join("#{name}.html").read) }

        it "links back to the start page" do
          expect(page.at_css("main a[href='/']")).to be_present
        end

        it "loads nothing from other hosts" do
          external = page.css("link[href], script[src], img[src]").map { it["href"] || it["src"] }

          expect(external.grep(%r{\A(https?:)?//})).to be_empty
        end

        it "names the app instead of showing the Rails default" do
          expect(page.at_css("title").text).to include("Done Today")
          expect(page.css("svg")).to be_empty
        end
      end
    end
  end
end
