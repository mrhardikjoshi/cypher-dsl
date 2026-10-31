# frozen_string_literal: true

# Every file under lib/ must define the constant Zeitwerk expects from its path,
# so that no constant depends on another file having been loaded first.
RSpec.describe 'Zeitwerk' do
  it 'eager loads the whole gem' do
    expect { Zeitwerk::Loader.eager_load_all }.not_to raise_error
  end
end
