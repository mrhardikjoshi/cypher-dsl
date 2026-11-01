# frozen_string_literal: true

# Translated from renderer/ConfigurationTests.java.
module CypherDSL
  RSpec.describe 'ConfigurationTests' do
    let(:cfg0) { Renderer::Configuration.new_config.build }
    let(:cfg1) { Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_5_DEFAULT_CYPHER).build }
    let(:cfg2) { Renderer::Configuration.new_config.with_dialect(Renderer::Dialect::NEO4J_4).build }

    it 'dialect should be included in equals' do
      expect(cfg0).to eq(cfg1)
      expect(cfg0).not_to eq(cfg2)
    end

    it 'dialect should be included in hash' do
      expect(cfg0.hash).to eq(cfg1.hash)
      expect(cfg0.hash).not_to eq(cfg2.hash)
    end
  end
end
