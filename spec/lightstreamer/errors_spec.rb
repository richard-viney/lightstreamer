describe Lightstreamer::Errors do
  describe Lightstreamer::Errors::MetadataAdapterError do
    it 'initializes from an error message and error code' do
      error = described_class.new 'message', -5

      expect(error.adapter_error_message).to eq('message')
      expect(error.adapter_error_code).to eq(-5)
    end
  end

  describe Lightstreamer::Errors::SessionEndError do
    it 'initializes from a cause code' do
      error = described_class.new '30'

      expect(error.cause_code).to eq(30)
    end
  end

  describe Lightstreamer::LightstreamerError do
    it 'builds the correct error type for each numeric code' do
      {
        1 => Lightstreamer::Errors::AuthenticationError,
        2 => Lightstreamer::Errors::UnknownAdapterSetError,
        3 => Lightstreamer::Errors::IncompatibleSessionError,
        7 => Lightstreamer::Errors::LicensedMaximumSessionsReachedError,
        8 => Lightstreamer::Errors::ConfiguredMaximumSessionsReachedError,
        9 => Lightstreamer::Errors::ConfiguredMaximumServerLoadReachedError,
        10 => Lightstreamer::Errors::NewSessionsTemporarilyBlockedError,
        11 => Lightstreamer::Errors::StreamingNotAvailableError,
        13 => Lightstreamer::Errors::TableModificationNotAllowedError,
        17 => Lightstreamer::Errors::InvalidDataAdapterError,
        19 => Lightstreamer::Errors::UnknownTableError,
        21 => Lightstreamer::Errors::InvalidItemError,
        22 => Lightstreamer::Errors::InvalidItemForFieldsError,
        23 => Lightstreamer::Errors::InvalidFieldError,
        24 => Lightstreamer::Errors::UnsupportedModeForItemError,
        25 => Lightstreamer::Errors::InvalidSelectorError,
        26 => Lightstreamer::Errors::UnfilteredDispatchingNotAllowedForItemError,
        27 => Lightstreamer::Errors::UnfilteredDispatchingNotSupportedForItemError,
        28 => Lightstreamer::Errors::UnfilteredDispatchingNotAllowedByLicenseError,
        29 => Lightstreamer::Errors::RawModeNotAllowedByLicenseError,
        30 => Lightstreamer::Errors::SubscriptionsNotAllowedByLicenseError,
        32 => Lightstreamer::Errors::InvalidProgressiveNumberError,
        33 => Lightstreamer::Errors::InvalidProgressiveNumberError,
        34 => Lightstreamer::Errors::IllegalMessageError,
        38 => Lightstreamer::Errors::MessagesSkippedByTimeoutError,
        39 => Lightstreamer::Errors::MessagesSkippedByTimeoutError,
        60 => Lightstreamer::Errors::ClientVersionNotSupportedError
      }.each do |error_code, error_class|
        expect(described_class.build('', error_code)).to be_a(error_class)
      end
    end

    it 'builds a metadata adapter error when the numeric code is negative' do
      expect(Lightstreamer::Errors::MetadataAdapterError).to receive(:new).with('message', -5)

      described_class.build 'message', '-5'
    end

    it 'builds a base error when the numeric code is unknown' do
      expect(described_class).to receive(:new).with('999: message')

      described_class.build 'message', '999'
    end
  end
end
