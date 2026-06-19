require "rails_helper"

RSpec.describe ArrayInclusionValidator, type: :model do
  let(:test_class) do
    Class.new do
      include ActiveModel::Model
      attr_accessor :items

      def self.name
        "TestClass"
      end
    end
  end

  it "is valid when all elements are in the inclusion list" do
    test_class.validates :items, array_inclusion: { in: %w[apple banana] }
    record = test_class.new(items: %w[apple banana])
    expect(record).to be_valid
  end

  it "is invalid when any element is not in the inclusion list" do
    test_class.validates :items, array_inclusion: { in: %w[apple banana] }
    record = test_class.new(items: %w[apple cherry])
    expect(record).not_to be_valid
    expect(record.errors[:items]).to be_present
  end

  it "supports validation via proc" do
    test_class.validates :items, array_inclusion: { proc: ->(val) { val.start_with?("a") } }
    record = test_class.new(items: %w[apple apricot])
    expect(record).to be_valid

    record2 = test_class.new(items: %w[apple banana])
    expect(record2).not_to be_valid
  end

  it "interpolates rejected values into custom messages" do
    test_class.validates :items, array_inclusion: {
      in: %w[apple banana],
      message: "rejected %{rejected_values}"
    }
    record = test_class.new(items: %w[apple cherry date])
    record.valid?
    expect(record.errors[:items].first).to eq("rejected \"cherry\", \"date\"")
  end
end
