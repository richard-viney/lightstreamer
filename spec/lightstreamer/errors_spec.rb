describe Lightstreamer::MetadataAdapterError do
  it 'constructs from an error message and error code' do
    error = Lightstreamer::MetadataAdapterError.new 'message', -5

    expect(error.adapter_error_message).to eq('message')
    expect(error.adapter_error_code).to eq(-5)
  end
end

describe Lightstreamer::SessionEndError do
  it 'constructs from a cause code' do
    error = Lightstreamer::SessionEndError.new '30'

    expect(error.cause_code).to eq(30)
  end
end

describe Lightstreamer::RequestError do
  it 'constructs from an error message and error code' do
    error = Lightstreamer::RequestError.new 'message', 404

    expect(error.request_error_message).to eq('message')
    expect(error.request_error_code).to eq(404)
    expect(error.message).to eq('404: message')
  end

  it 'constructs from an error message' do
    error = Lightstreamer::RequestError.new 'message', 0

    expect(error.request_error_message).to eq('message')
    expect(error.request_error_code).to eq(0)
    expect(error.message).to eq('message')
  end
end

describe Lightstreamer::LightstreamerError do
  it 'builds the correct error type based on the numeric code' do
    {
      1 => Lightstreamer::AuthenticationError,
      2 => Lightstreamer::UnknownAdapterSetError,
      3 => Lightstreamer::IncompatibleSessionError,
      7 => Lightstreamer::LicensedMaximumSessionsReachedError,
      8 => Lightstreamer::ConfiguredMaximumSessionsReachedError,
      9 => Lightstreamer::ConfiguredMaximumServerLoadReachedError,
      10 => Lightstreamer::NewSessionsTemporarilyBlockedError,
      11 => Lightstreamer::StreamingNotAvailableError,
      13 => Lightstreamer::TableModificationNotAllowedError,
      17 => Lightstreamer::InvalidDataAdapterError,
      19 => Lightstreamer::UnknownTableError,
      21 => Lightstreamer::InvalidItemError,
      22 => Lightstreamer::InvalidItemForFieldsError,
      23 => Lightstreamer::InvalidFieldError,
      24 => Lightstreamer::UnsupportedModeForItemError,
      25 => Lightstreamer::InvalidSelectorError,
      26 => Lightstreamer::UnfilteredDispatchingNotAllowedForItemError,
      27 => Lightstreamer::UnfilteredDispatchingNotSupportedForItemError,
      28 => Lightstreamer::UnfilteredDispatchingNotAllowedByLicenseError,
      29 => Lightstreamer::RawModeNotAllowedByLicenseError,
      30 => Lightstreamer::SubscriptionsNotAllowedByLicenseError,
      32 => Lightstreamer::InvalidProgressiveNumberError,
      33 => Lightstreamer::InvalidProgressiveNumberError,
      60 => Lightstreamer::ClientVersionNotSupportedError
    }.each do |error_code, error_class|
      expect(Lightstreamer::LightstreamerError.build('', error_code)).to be_a(error_class)
    end
  end

  it 'builds a metadata adapter error when the numeric code is negative' do
    expect(Lightstreamer::MetadataAdapterError).to receive(:new).with('message', -5)

    Lightstreamer::LightstreamerError.build 'message', '-5'
  end

  it 'builds a base error when the numeric code is unknown' do
    expect(Lightstreamer::LightstreamerError).to receive(:new).with('999: message')

    Lightstreamer::LightstreamerError.build 'message', '999'
  end
end
