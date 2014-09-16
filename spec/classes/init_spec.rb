require 'spec_helper'
describe 'hostidentity' do

  context 'with defaults for all parameters' do
    it { should contain_class('hostidentity') }
  end
end
