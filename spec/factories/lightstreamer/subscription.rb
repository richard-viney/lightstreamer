FactoryGirl.define do
  factory :subscription, class: Lightstreamer::Subscription do
    items []
    fields []
    mode :merge
    adapter nil
    maximum_update_frequency nil

    initialize_with do
      new items: items, fields: fields, mode: mode, adapter: adapter, maximum_update_frequency: maximum_update_frequency
    end
  end
end
