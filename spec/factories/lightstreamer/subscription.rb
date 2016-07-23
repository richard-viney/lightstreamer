FactoryGirl.define do
  factory :subscription, class: Lightstreamer::Subscription do
    items []
    fields []
    mode :merge
    adapter nil

    initialize_with { new items: items, fields: fields, mode: mode, adapter: adapter }
  end
end
