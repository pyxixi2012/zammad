require 'rails_helper'
require 'import/factory_examples'

RSpec.describe Import::OTRS::UserFactory do
  it_behaves_like 'Import::Factory'

  it 'skips root@localhost' do

    root_data = json_fixture('import/otrs/user/default')
    expect(Import::OTRS::User).to_not receive(:new)

    described_class.import([root_data])
  end
end
