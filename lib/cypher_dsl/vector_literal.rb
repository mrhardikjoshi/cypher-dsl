# frozen_string_literal: true

module CypherDSL
  # `vector([1, 2, 3], 3, INTEGER NOT NULL)`: a typed vector literal. The Java
  # overloads per primitive array become an optional type: `:integer8`,
  # `:integer16`, `:integer32`, `:integer` (default for integers), `:float32`
  # and `:float` (default for floats).
  class VectorLiteral
    include Expression

    TYPES = { integer8: 'INTEGER8', integer16: 'INTEGER16', integer32: 'INTEGER32', integer: 'INTEGER',
              float32: 'FLOAT32', float: 'FLOAT' }.freeze
    FLOAT_TYPES = %i[float32 float].freeze
    MAX_SIZE = 4096

    attr_reader :content, :type

    def self.of(elements, type = nil)
      raise ArgumentError, 'Vector elements must not be literal null' if elements.nil?

      size = elements.size
      unless (1..MAX_SIZE).cover?(size)
        raise ArgumentError,
              "'#{size}' is not a valid value. Must be a number in the range 1 to #{MAX_SIZE} (GQL 42N31)"
      end

      new(elements, type || (elements.all?(Integer) ? :integer : :float))
    end

    def initialize(content, type)
      raise ArgumentError, "Unknown vector type #{type.inspect}" unless TYPES.key?(type)

      @type = type
      @content = (FLOAT_TYPES.include?(type) ? content.map(&:to_f) : content.map(&:to_i)).freeze
      freeze
    end

    # The literal as Cypher text; it does not depend on any rendering option.
    def as_string = "vector([#{content.join(', ')}], #{content.size}, #{TYPES[type]} NOT NULL)"
  end
end
