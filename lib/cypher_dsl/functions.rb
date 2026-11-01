# frozen_string_literal: true

module CypherDSL
  # Factory methods for Cypher's built-in functions, mixed into {Cypher}
  # (`Cypher.to_upper(name)`, `Cypher.date(year: …)`). Names follow the Java
  # `Functions` class in snake_case; `*_distinct` variants render `DISTINCT`
  # inside the call. Arguments are coerced, so plain strings and numbers become
  # literals and `nil` becomes `NULL`.
  module Functions
    # A call of any function with the given arguments, coerced to expressions.
    def function(name, *arguments) = FunctionInvocation.new(name, arguments.map { |a| Expression.coerce(a) })

    # --- strings ---------------------------------------------------------

    def left(expression, length) = string_side('left', expression, length)
    def right(expression, length) = string_side('right', expression, length)
    def ltrim(expression) = function('ltrim', expression)
    def rtrim(expression) = function('rtrim', expression)
    def trim(expression) = function('trim', expression)
    def to_lower(expression) = function('toLower', expression)
    def to_upper(expression) = function('toUpper', expression)
    def reverse(expression) = function('reverse', expression)
    def replace(original, search, replacement) = function('replace', original, search, replacement)
    def split(expression, delimiter) = function('split', expression, delimiter)
    def to_string_or_null(expression) = function('toStringOrNull', expression)

    def substring(original, start, length = nil)
      raise ArgumentError, 'start is required' if start.nil?

      function('substring', original, start, *[length].compact)
    end

    # --- aggregates ------------------------------------------------------

    def avg(expression) = function('avg', expression)
    def avg_distinct(expression) = distinct_function('avg', expression)
    def collect(expression) = function('collect', expression)
    def collect_distinct(expression) = distinct_function('collect', expression)
    def count(expression) = function('count', expression)
    def count_distinct(expression) = distinct_function('count', expression)
    def max(expression) = function('max', expression)
    def max_distinct(expression) = distinct_function('max', expression)
    def min(expression) = function('min', expression)
    def min_distinct(expression) = distinct_function('min', expression)
    def sum(expression) = function('sum', expression)
    def sum_distinct(expression) = distinct_function('sum', expression)
    def percentile_cont(expression, percentile) = function('percentileCont', expression, percentile)
    def percentile_cont_distinct(expression, percentile) = distinct_function('percentileCont', expression, percentile)
    def percentile_disc(expression, percentile) = function('percentileDisc', expression, percentile)
    def percentile_disc_distinct(expression, percentile) = distinct_function('percentileDisc', expression, percentile)
    def st_dev(expression) = function('stDev', expression)
    def st_dev_distinct(expression) = distinct_function('stDev', expression)
    def st_dev_p(expression) = function('stDevP', expression)
    def st_dev_p_distinct(expression) = distinct_function('stDevP', expression)

    # --- lists, paths and entities ---------------------------------------

    def head(expression) = function('head', expression)
    def last(expression) = function('last', expression)
    def tail(expression) = function('tail', expression)
    def keys(expression) = function('keys', expression)
    def properties(expression) = function('properties', expression)

    def coalesce(*expressions)
      raise ArgumentError, 'The expression for coalesce() is required.' if expressions.flatten.empty?

      function('coalesce', *expressions)
    end

    def is_empty(expression) = function('isEmpty', expression)
    def range(start_value, end_value, step = nil) = function('range', start_value, end_value, *[step].compact)
    def nodes(path) = function('nodes', path.required_symbolic_name)
    def relationships(path) = function('relationships', path.required_symbolic_name)
    def length(path) = function('length', path.required_symbolic_name)
    def labels(node) = function('labels', node.required_symbolic_name)
    def type(relationship) = function('type', relationship.required_symbolic_name)
    def start_node(relationship) = function('startNode', relationship.required_symbolic_name)
    def end_node(relationship) = function('endNode', relationship.required_symbolic_name)
    def element_id(element) = function('elementId', element.required_symbolic_name)

    # `id(n)`; deprecated in Neo4j 5 in favour of {#element_id}, kept for parity.
    def id(element) = function('id', element.required_symbolic_name)

    # `reduce(acc = initial, x IN list | mapper)`, built as
    # `reduce(:x).in(list).map(mapper).accumulate_on(acc).with_initial_value_of(0)`.
    def reduce(variable) = Reduction.of(variable)

    # --- scalars and conversions -----------------------------------------

    def to_integer(expression) = function('toInteger', expression)
    def to_float(expression) = function('toFloat', expression)
    def to_string(expression) = function('toString', expression)
    def to_boolean(expression) = function('toBoolean', expression)
    def random_uuid = function('randomUUID')

    # `linenumber()` and `file()`, available inside LOAD CSV.
    def linenumber = function('linenumber')
    def file = function('file')

    # --- mathematical ----------------------------------------------------

    def abs(expression) = function('abs', expression)
    def ceil(expression) = function('ceil', expression)
    def floor(expression) = function('floor', expression)
    def sign(expression) = function('sign', expression)
    def exp(expression) = function('exp', expression)
    def log(expression) = function('log', expression)
    def log10(expression) = function('log10', expression)
    def sqrt(expression) = function('sqrt', expression)
    def acos(expression) = function('acos', expression)
    def asin(expression) = function('asin', expression)
    def atan(expression) = function('atan', expression)
    def atan2(y, x) = function('atan2', y, x)
    def cos(expression) = function('cos', expression)
    def cot(expression) = function('cot', expression)
    def degrees(expression) = function('degrees', expression)
    def haversin(expression) = function('haversin', expression)
    def radians(expression) = function('radians', expression)
    def sin(expression) = function('sin', expression)
    def tan(expression) = function('tan', expression)
    def e = function('e')
    def pi = function('pi')
    def rand = function('rand')

    # `round(value)`, `round(value, precision)` or `round(value, precision, mode)`.
    def round(value, *arguments)
      raise ArgumentError, 'round() takes a value, an optional precision and an optional mode' if arguments.size > 2

      function('round', value, *arguments)
    end

    # --- spatial ---------------------------------------------------------

    def point(expression) = function('point', expression)
    def cartesian(x, y) = point(MapExpression.of('x', x, 'y', y))
    def coordinate(longitude, latitude) = point(MapExpression.of('longitude', longitude, 'latitude', latitude))
    def within_bbox(point, lower_left, upper_right) = function('point.withinBBox', point, lower_left, upper_right)

    # `distance(a, b)`; rendered as `point.distance(a, b)` on Neo4j 5.
    def distance(point1, point2) = function('distance', point1, point2)

    # --- temporal --------------------------------------------------------

    # `date()`, `date('2020-09-15')`, `date({year: 2020})`, `date($p)` or `date(timezone: 'Europe/Berlin')`;
    # the same for datetime, localdatetime, localtime and time.
    def date(value = nil, timezone: nil) = temporal('date', value, timezone)
    def datetime(value = nil, timezone: nil) = temporal('datetime', value, timezone)
    def localdatetime(value = nil, timezone: nil) = temporal('localdatetime', value, timezone)
    def localtime(value = nil, timezone: nil) = temporal('localtime', value, timezone)
    def time(value = nil, timezone: nil) = temporal('time', value, timezone)
    def duration(value) = function('duration', value)

    def calendar_date(year, month = nil, day = nil) = date(date_components(year:, month:, day:))
    def week_date(year, week = nil, day_of_week = nil) = date(date_components(year:, week:, dayOfWeek: day_of_week))
    def ordinal_date(year, ordinal_day = nil) = date(date_components(year:, ordinalDay: ordinal_day))

    def quarter_date(year, quarter = nil, day_of_quarter = nil)
      date(date_components(year:, quarter:, dayOfQuarter: day_of_quarter))
    end

    # --- graphs (composite databases) ------------------------------------

    def graph_names = function('graph.names')
    def graph_properties_by_name(name) = function('graph.propertiesByName', name)
    def graph_by_name(name) = function('graph.byName', name)

    private

    def distinct_function(name, *arguments)
      FunctionInvocation.new(name, arguments.map { |a| Expression.coerce(a) }, distinct: true)
    end

    def string_side(name, expression, length)
      raise ArgumentError, 'length might not be null when the expression is not null' if !expression.nil? && length.nil?

      function(name, expression, length)
    end

    def temporal(name, value, timezone)
      raise ArgumentError, "#{name}() takes either a value or a timezone, not both" if value && timezone
      return function(name, MapExpression.of('timezone', timezone)) if timezone

      value.nil? ? function(name) : function(name, value)
    end

    def date_components(**components)
      raise ArgumentError, 'year is required' if components[:year].nil?

      MapExpression.of(components.compact.transform_keys(&:to_s))
    end
  end
end
