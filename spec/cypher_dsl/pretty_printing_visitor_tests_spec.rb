# frozen_string_literal: true

# Translated from renderer/PrettyPrintingVisitorTests.java.
#
# Adapted: the pretty printing visitor escapes names only when necessary, which is
# `Renderer::Escaper.escape_if_necessary`; checked end to end through a pretty printing renderer.
module CypherDSL
  RSpec.describe 'PrettyPrintingVisitorTests' do
    let(:renderer) do
      Renderer.get_renderer(Renderer::Configuration.new_config
                                                   .always_escape_names(false)
                                                   .with_indent_style(:tab)
                                                   .with_indent_size(4)
                                                   .build)
    end

    {
      'ALabel' => 'ALabel',
      'A Label' => '`A Label`',
      'A `Label' => '`A ``Label`',
      '`A `Label' => '```A ``Label`',
      'Spring Data Neo4j⚡️RX' => '`Spring Data Neo4j⚡️RX`'
    }.each do |name, expected_escaped_name|
      it "correctly escapes names(#{name})" do
        expect(Renderer::Escaper.escape_if_necessary(name)).to eq(expected_escaped_name)
        statement = Cypher.match(Cypher.node(name).named(:n)).returning(:n).build
        expect(renderer.render(statement)).to eq("MATCH (n:#{expected_escaped_name}) RETURN n")
      end
    end

    it 'does not try to escape null names' do
      expect(Renderer::Escaper.escape_if_necessary(nil)).to be_nil
    end
  end
end
