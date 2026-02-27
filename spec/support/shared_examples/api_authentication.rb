RSpec.shared_examples "requires API key" do
  context "without authentication" do
    it "returns 401" do
      action_without_auth
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
