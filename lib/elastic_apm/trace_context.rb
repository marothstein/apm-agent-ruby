# frozen_string_literal: true

module ElasticAPM
  # @api private
  class TraceContext
    class InvalidTraceparentHeader < StandardError; end

    VERSION = '00'
    HEX_REGEX = /[^[:xdigit:]]/.freeze

    def initialize(
      version: VERSION,
      trace_id: nil,
      span_id: nil,
      recorded: true
    )
      @version = version
      @trace_id = trace_id
      @span_id = span_id
      @recorded = recorded
    end

    attr_accessor :version, :trace_id, :span_id, :recorded

    alias :recorded? :recorded

    def self.for_transaction(sampled: true)
      new.tap do |t|
        t.trace_id = SecureRandom.hex(16)
        t.span_id = SecureRandom.hex(8)
        t.recorded = sampled
      end
    end

    def self.for_span
      new.tap do |t|
        t.trace_id = SecureRandom.hex(16)
        t.span_id = SecureRandom.hex(8)
        t.recorded = true
      end
    end

    # rubocop:disable Metrics/AbcSize
    def self.parse(header)
      raise InvalidTraceparentHeader unless header.length == 55
      raise InvalidTraceparentHeader unless header[0..1] == VERSION

      new.tap do |t|
        t.version, t.trace_id, t.span_id, t.flags =
          header.split('-').tap do |values|
            values[-1] = Util.hex_to_bits(values[-1])
          end

        raise InvalidTraceparentHeader if HEX_REGEX =~ t.trace_id
        raise InvalidTraceparentHeader if HEX_REGEX =~ t.span_id
      end
    end
    # rubocop:enable Metrics/AbcSize

    def flags=(flags)
      @flags = flags

      self.recorded = flags[7] == '1'
    end

    def flags
      format('0000000%d', recorded? ? 1 : 0)
    end

    def hex_flags
      format('%02x', flags.to_i(2))
    end

    def child
      dup.tap { |tc| tc.span_id = SecureRandom.hex(8) }
    end

    def to_header
      format('%s-%s-%s-%s', version, trace_id, span_id, hex_flags)
    end
  end
end
