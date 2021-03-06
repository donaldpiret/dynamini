module Dynamini
  module TypeHandler

    GETTER_PROCS = {
        integer:  proc { |v| v.to_i },
        date:     proc { |v| v.is_a?(Date) ? v : Time.at(v).to_date },
        time:     proc { |v| Time.at(v.to_f) },
        float:    proc { |v| v.to_f },
        symbol:   proc { |v| v.to_sym },
        string:   proc { |v| v.to_s },
        boolean:  proc { |v| v },
        array:    proc { |v| v.is_a?(Enumerable) ? v.to_a : [v] },
        set:      proc { |v| v.is_a?(Enumerable) ? Set.new(v) : Set.new([v]) }
    }

    SETTER_PROCS = {
        integer:  proc { |v| v.to_i },
        time:     proc { |v| (v.is_a?(Date) ? v.to_time : v).to_f },
        float:    proc { |v| v.to_f },
        symbol:   proc { |v| v.to_s },
        string:   proc { |v| v.to_s },
        boolean:  proc { |v| v },
        date:     proc { |v| v.to_time.to_f },
        array:    proc { |v| v.is_a?(Enumerable) ? v.to_a : [v] },
        set:      proc { |v| v.is_a?(Enumerable) ? Set.new(v) : Set.new([v]) }
    }

    def handle(column, format_class, options = {})
      validate_handle(format_class, options)

      options[:default] ||= format_default(format_class)
      options[:default] ||= Set.new if format_class == :set

      self.handles = self.handles.merge(column => { format: format_class, options: options })

      define_handled_getter(column, format_class, options)
      define_handled_setter(column, format_class)
    end

    def define_handled_getter(column, format_class, _options = {})
      proc = GETTER_PROCS[format_class]
      fail 'Unsupported data type: ' + format_class.to_s if proc.nil?

      define_method(column) do
        read_attribute(column)
      end
    end

    def define_handled_setter(column, format_class)
      method_name = (column.to_s + '=')
      proc = SETTER_PROCS[format_class]
      fail 'Unsupported data type: ' + format_class.to_s if proc.nil?
      define_method(method_name) do |value|
        write_attribute(column, value)
      end
    end

    def format_default(format_class)
      case format_class
        when :array
          []
        when :set
          Set.new
      end
    end

    def validate_handle(format, options)
      if format == :set
        if options[:of] && [:set, :array].include?(options[:of])
          raise ArgumentError, 'Invalid handle: cannot store non-primitive datatypes within a set.'
        end
      end
    end

    def handled_key(column, value)
      if handles[column]
        attribute_callback(GETTER_PROCS, handles[column], value, false)
      else
        value
      end
    end

    def attribute_callback(procs, handle, value, validate)
      callback = procs[handle[:format]]
      if should_convert_elements?(handle, value)
        result = convert_elements(value, procs[handle[:options][:of]])
        callback.call(result)
      elsif validate && invalid_enumerable_value?(handle, value)
        raise ArgumentError, "Can't write a non-enumerable value to field handled as #{handle[:format]}"
      else
        callback.call(value)
      end
    end

    def should_convert_elements?(handle, value)
      handle[:options][:of] && (value.is_a?(Array) || value.is_a?(Set))
    end

    def invalid_enumerable_value?(handle, value)
      handled_as?(handle, [:array, :set]) && !value.is_a?(Enumerable)
    end

    def convert_elements(enumerable, callback)
      enumerable.map { |e| callback.call(e) }
    end

    def handled_as?(handle, type)
      type.include? handle[:format]
    end
  end
end
