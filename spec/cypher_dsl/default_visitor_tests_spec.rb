# frozen_string_literal: true

# Translated from renderer/DefaultVisitorTests.java.
#
# Adapted: the visitor's `escapeName` / `escapeIfNecessary` are `Renderer::Escaper.escape` /
# `escape_if_necessary`; `underscoresInEnumsShouldBeRemoved` concerns Java enum rendering.
# The textual sequence ``` (backslash, u, 0060) is spelled out with `92.chr` so that it
# is not confused with the backtick character itself.
module CypherDSL
  RSpec.describe 'DefaultVisitorTests' do
    backslash = 92.chr

    {
      'ALabel' => '`ALabel`',
      'A Label' => '`A Label`',
      'A `Label' => '`A ``Label`',
      '`A `Label' => '```A ``Label`',
      'Spring Data Neo4j⚡️RX' => '`Spring Data Neo4j⚡️RX`'
    }.each do |name, expected_escaped_name|
      it "correctly escapes names(#{name})" do
        expect(Renderer::Escaper.escape(name)).to eq(expected_escaped_name)
      end
    end

    it 'does not try to escape null names' do
      expect(Renderer::Escaper.escape_if_necessary(nil)).to be_nil
    end

    {
      'ABC' => 'ABC',
      'A C' => '`A C`',
      'A` C' => '`A`` C`',
      'A`` C' => '`A`` C`',
      'ALabel' => 'ALabel',
      'A Label' => '`A Label`',
      'A `Label' => '`A ``Label`',
      '`A `Label' => '```A ``Label`',
      'Spring Data Neo4j⚡️RX' => '`Spring Data Neo4j⚡️RX`',
      'Foo `' => '`Foo ```',
      "Foo #{backslash}u0060" => '`Foo ```',
      '`' => '````',
      '```' => '``````',
      'Hello`' => '`Hello```',
      'Hi````there' => '`Hi````there`',
      'Hi`````there' => '`Hi``````there`',
      '`a`b`c`' => '```a``b``c```',
      "#{backslash}u0060a`b`c#{backslash}u0060d#{backslash}u0060" => '```a``b``c``d```'
    }.each do |name, expected_escaped_name|
      it "escapes if necessary(#{name})" do
        expect(Renderer::Escaper.escape_if_necessary(name)).to eq(expected_escaped_name)
      end
    end

    it 'does not unnecessary escape' do
      expect(Renderer::Escaper.escape_if_necessary(' ')).to eq('` `')
      expect(Renderer::Escaper.escape_if_necessary(nil)).to be_nil
      expect(Renderer::Escaper.escape_if_necessary('a')).to eq('a')
    end
  end
end
