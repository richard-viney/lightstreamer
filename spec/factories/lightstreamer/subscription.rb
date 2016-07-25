FactoryGirl.define do
  factory :subscription, class: Lightstreamer::Subscription do
    items []
    fields []
    mode :merge
    adapter nil
    maximum_update_frequency nil
    selector nil

    initialize_with do
      new items: items, fields: fields, mode: mode, adapter: adapter, selector: selector,
          maximum_update_frequency: maximum_update_frequency
    end
  end
end
