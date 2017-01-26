require 'spec_helper'
describe 'conjur' do
  context 'with default values for all parameters' do
    it { should contain_class('conjur') }
  end
end
