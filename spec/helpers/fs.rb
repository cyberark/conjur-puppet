# frozen_string_literal: true

# FakeFS and MockFS both conflict with Puppet loaders
# so instead implement just what we need
module FsMock
  def self.included(example)
    example.before(:each) do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:read).and_call_original
    end
  end

  def mock_file(path, content)
    allow(File).to receive(:exist?).with(path).and_return(true)
    allow(File).to receive(:read).with(path).and_return(content)
  end
end
